"""A23-86 D - the monster kill record (KillLog) (게임성 개발 3, 2026-10-09), offline.

Every kill that paid a player adds to data.KillLog = { Total, M (by hand), A (auto combat), Golden, ByKind, ByTier }, kept from the
first beta day (the sticker book screen comes 11/04; nothing is paid here). Runs the CURRENT Config, Util and KillLog on
tools/fixtures/dev2_kit.luau + tools/fixtures/dev3_world.luau with tools/fixtures/kill_log_offline.luau and the installed official
Luau CLI. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies only.

Usage: py tools/test_kill_log.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-09/offline_dev3_kill_log_2026-10-09.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "LOG_SOURCE": SSS / "KillLog.luau",
}
C, L = "CONFIG_SOURCE", "LOG_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    ("personal monsters count", L, "	if type(info) ~= \"table\" or info.Personal == true then return end\n", "	if type(info) ~= \"table\" then return end\n"),
    ("unknown kinds count", L, " or not Config.MonsterTypes[info.Kind] then return end\n	local data", " then return end\n	local data"),
    ("no total", L, "	k.Total = math.min(CAP, k.Total + 1)\n", ""),
    ("auto counted as hand", L, "local auto = player:GetAttribute(\"AutoCombatEnabled\") == true", "local auto = false"),
    ("hand counted as auto", L, "local field = auto and \"A\" or \"M\"", "local field = auto and \"M\" or \"A\""),
    ("no per-kind count", L, "	k.ByKind[info.Kind] = math.min(CAP, (k.ByKind[info.Kind] or 0) + 1)\n", ""),
    ("no golden count", L, "	if info.Golden == true then k.Golden = math.min(CAP, k.Golden + 1) end\n", ""),
    ("golden for every kill", L, "if info.Golden == true then k.Golden", "if info.Golden ~= nil then k.Golden"),
    ("no per-tier count", L, "	row[field] = math.min(CAP, row[field] + 1)\n", ""),
    ("the tier is always 1", L, "local tier = math.clamp(math.floor(count(player:GetAttribute(\"WeaponTier\"))), 0, Config.MaxWeaponTier)", "local tier = 1"),
    ("no ceiling on the total", L, "	k.Total = math.min(CAP, k.Total + 1)\n", "	k.Total += 1\n"),
    ("no ceiling on the kind", L, "k.ByKind[info.Kind] = math.min(CAP, (k.ByKind[info.Kind] or 0) + 1)", "k.ByKind[info.Kind] = (k.ByKind[info.Kind] or 0) + 1"),
    ("no ceiling on the tier row", L, "row[field] = math.min(CAP, row[field] + 1)", "row[field] = row[field] + 1"),
    ("no repair of the numbers", L, "	k.Total, k.M, k.A, k.Golden = count(k.Total), count(k.M), count(k.A), count(k.Golden)\n", ""),
    ("unknown kinds kept", L, "if type(kind) == \"string\" and Config.MonsterTypes[kind] then kinds[kind] = count(n) end", "if type(kind) == \"string\" then kinds[kind] = count(n) end"),
    ("any tier key kept", L, "if type(key) == \"string\" and tier and tier == math.floor(tier) and tier >= 0 and tier <= Config.MaxWeaponTier and type(t) == \"table\" then", "if type(key) == \"string\" and type(t) == \"table\" then"),
    ("tiers above the last kept", L, "tier >= 0 and tier <= Config.MaxWeaponTier", "tier >= 0"),
    ("fractions kept", L, "k.Total, k.M, k.A, k.Golden = count(k.Total), count(k.M), count(k.A), count(k.Golden)\n", "k.Total, k.M, k.A, k.Golden = k.Total, k.M, k.A, k.Golden\n"),
    ("a broken table is kept", L, "	if type(k) ~= \"table\" then\n		k = {}\n		data.KillLog = k\n	end\n", ""),
    ("not repaired at join", L, "			local ok, err = pcall(record, data)\n", "			local ok, err = true, nil\n"),
    ("config: no default", C, "Config.Data.Defaults.KillLog = { Total = 0, M = 0, A = 0, Golden = 0, ByKind = {}, ByTier = {} }\n", ""),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    main = read(SSS / "Main.server.luau")
    init = re.search(r"local INIT_ORDER = \{(.*?)\n\}", main, re.S)
    start = re.search(r"local START_ORDER = \{(.*?)\n\}", main, re.S)
    names = re.compile(r'"(\w+)"')
    init_list = names.findall(init.group(1)) if init else []
    start_list = names.findall(start.group(1)) if start else []
    check(init_list.count("KillLog") == 1 and start_list.count("KillLog") == 1, "KillLog is in both lists once")
    check(start_list.index("KillLog") < start_list.index("PlayerService") and start_list[-1] == "PlayerService", "KillLog starts before PlayerService")
    check((SSS / "KillLog.luau").is_file(), "the service file exists")
    check(sorted(init_list) == sorted(start_list), "every service is in both lists")
    log = read(SSS / "KillLog.luau")
    code = "\n".join(l.split("--", 1)[0] for l in log.splitlines())
    check("MonsterKilled:Connect" in code, "KillLog listens to MonsterKilled")
    check("AddBankGold" not in code and "AddStat" not in code and "AddXP" not in code and "GrantItem" not in code, "it pays nothing")
    return count, failures


SUITE = Suite(
    mark="KILLLOG",
    fixture=ROOT / "tools/fixtures/kill_log_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-09/offline_dev3_kill_log_2026-10-09.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-86 D: every kill that paid the player (MonsterService.MonsterKilled, not personal tutorial monsters, only "
             "known monster kinds) adds to data.KillLog = { Total, M (by hand) / A (auto combat: the player attribute "
             "AutoCombatEnabled at that moment), Golden, ByKind[kind], ByTier[weapon tier 0..8] = { M, A } }; whole numbers "
             "0..1,000,000,000; the table is repaired at join (known kinds / tiers only); pays nothing.",
    limitations="The sticker book screen, rewards and titles come 11/04. Auto-combat is the attribute at the kill, as the "
                "story's AutoKill (MonsterKilled carries no auto flag).",
)

if __name__ == "__main__":
    run(SUITE)
