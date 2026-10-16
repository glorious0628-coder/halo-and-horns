"""빛 마을 점검 #41 (user 2026-10-10, (b)): no hitting the Active kaiju from inside a faction town, offline.

Runs the same CURRENT sources as tools/test_ranking.py (whole PvPService, CombatService, GrudgeService, RankingService,
AnnounceService, LootService, TitleService, Config, Util + the PlayerService fame / activity extract) on
tools/fixtures/dev2_world.luau (rankWorld) with tools/fixtures/kaiju_town_offline.luau, with the installed official
Luau CLI. No Studio, network, DataStore or Roblox API calls. Mutations run on in-memory copies of the sources only.

Spec: docs/design/zone_check_halo_2026-10-10.md #41 (검수 relayed the user's (b), 2026-10-10).
Usage: py tools/test_kaiju_town.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-10/offline_dev2_kaiju_town_2026-10-10.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SSS, Suite, function_block, read, run
from test_ranking import FILES as RANKING_FILES, bindings

FILES = dict(RANKING_FILES)
P, C, K = "PVP_SOURCE", "CONFIG_SOURCE", "KAIJU_SOURCE"


def kaiju_bindings(sources: dict[str, str]) -> dict[str, str]:
    out = bindings(sources)
    kaiju = sources[K]
    # KaijuService's HP count of the Halo fighters near the kaiju (cut out; its helpers come from the fixture)
    out["KAIJU_COUNT_EXTRACT"] = (
        "local Config, Util, S, readyPlayers, factionOf = ...\n"
        + function_block(kaiju, "local function inFactionTown(")
        + function_block(kaiju, "local function friendOfKaiju(")  # A23-113 ①: friends of the kaiju never count
        + function_block(kaiju, "local function countNearbyHalo(")
        + "\nreturn countNearbyHalo\n")
    return out

MUTATIONS = [
    ("A23-220: the kaiju hit anywhere outside the faction towns", P,
     "not inFactionTown(attacker) and inPvP(attacker) and inPvP(victim) then", "not inFactionTown(attacker) then"),
    ("A23-220: one of the two in a red zone is enough", P, "and inPvP(attacker) and inPvP(victim) then",
     "and (inPvP(attacker) or inPvP(victim)) then"),
    ("the Crossroads blocks too", P, "zone.Town == true and zone.Faction ~= nil", "zone.Town == true"),
    ("never in a faction town", P, '\treturn ok and type(zone) == "table" and zone.Town == true and zone.Faction ~= nil\n',
     "\treturn false\n"),
    ("the kaiju's HP counts Halo players in their town", K, " and Util.IsAlive(v) and not inFactionTown(v) then",
     " and Util.IsAlive(v) then"),
    ("KaijuService ignores the faction-town rule", K, "\treturn ok and inTown == true\nend", "\treturn false\nend"),
    ("PvPService.InFactionTown always false", P, "function PvPService.InFactionTown(p)\n\treturn inFactionTown(p)\nend",
     "function PvPService.InFactionTown(p)\n\treturn false\nend"),
    ("the Crossroads gets a faction", C, 'MinLevel = 1, PvP = false, Town = true, Faction = nil,',
     'MinLevel = 1, PvP = false, Town = true, Faction = "Halo",'),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    pvp = read(SSS / "PvPService.luau")
    can = function_block(pvp, "function PvPService.CanAttack(")
    check("inFactionTown(attacker)" in can, "CanAttack asks where the attacker stands for the kaiju exception")
    check(can.find("inFactionTown(attacker)") < can.find("inPvP(attacker)"),
          "the town rule sits on the kaiju exception, before the normal safe-zone rule")
    return count, failures


SUITE = Suite(
    mark="KAIJU_TOWN",
    fixture=ROOT / "tools/fixtures/kaiju_town_offline.luau",
    world=ROOT / "tools/fixtures/dev2_world.luau",
    out=ROOT / "docs/art/verification_2026-10-10/offline_dev2_kaiju_town_2026-10-10.json",
    files=FILES, bindings=kaiju_bindings, mutations=MUTATIONS, static=static,
    contract="#41 (b): PvPService.CanAttack's kaiju exception (a Halo player may hit the Active kaiju in any zone, rookies "
             "allowed, protection ignored) does not apply while the attacker stands in a faction town (Config.Zones "
             "Town = true with a Faction: Halo Citadel, Horns Den); then the normal rules answer (a town is a safe zone, "
             "'SafeZone'). The Crossroads (a town without a faction) and every zone outside the towns keep the exception; "
             "where the kaiju stands does not matter; a queued kaiju and Horns attackers never had the exception. "
             "KaijuService's HP count (countNearbyHalo, HPPerNearbyHalo) skips Halo players standing in a faction town "
             "(PvPService.InFactionTown): they cannot fight it; the Crossroads still counts.",
    limitations="The zone comes from a ZoneService double (Config.Zones by id); the real ZoneService samples positions "
                "once a second. Client feedback for a blocked hit is unchanged (the same as any safe-zone hit).",
)

if __name__ == "__main__":
    run(SUITE)
