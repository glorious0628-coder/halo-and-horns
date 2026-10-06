"""BB14 KO screen, server part: the owner-only Net.Fx "KO" payload of CombatService's death pipeline, offline.

Runs the same CURRENT sources as tools/test_ranking.py (whole CombatService, PvPService, GrudgeService, RankingService,
AnnounceService, LootService, TitleService, Config, Util + the PlayerService fame / activity extract) on
tools/fixtures/dev2_world.luau with tools/fixtures/ko_screen_offline.luau, with the installed official Luau CLI.
No Studio, network, DataStore or Roblox API calls. Mutations run on in-memory copies of the sources only.

Spec: docs/design/beta_basics_2026-10-05.md "### BB14." (Server contract).
Usage: py tools/test_ko_screen.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_dev2_ko_screen_2026-10-06.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run
from test_ranking import FILES as RANKING_FILES, bindings

FILES = dict(RANKING_FILES)
CO, C, K = "COMBAT_SOURCE", "CONFIG_SOURCE", "KAIJU_SOURCE"

MUTATIONS = [
    ("the source kind is never recorded", CO,
     'if attacker == nil and type(sourceKind) == "string" then lastSource[victim] = { Kind = sourceKind, T = now } end', ""),
    ("a player's hit records a monster source", CO,
     'if attacker == nil and type(sourceKind) == "string" then', 'if type(sourceKind) == "string" then'),
    ("any old hit is the cause", CO, "local recent = src ~= nil and ctx.At - src.T <= D.SourceSeconds", "local recent = src ~= nil"),
    ("the source outlives the death", CO, "\tlastPvPAttacker[victim] = nil\n\tlastSource[victim] = nil\nend", "\tlastPvPAttacker[victim] = nil\nend"),
    ("monster before player", CO, "\tif killer then\n\t\tby, name, killerFaction = \"Player\"",
     "\tif killer and not recent then\n\t\tby, name, killerFaction = \"Player\""),
    ("an unknown kind counts as a monster", CO, 'elseif recent and Config.MonsterTypes[src.Kind] then', 'elseif recent and src.Kind ~= "Kaiju" then'),
    ("no fall below the floor", CO, "\t\tor died.Pos.Y < (Config.ZoneAt(died.Pos).Center.Y or 0) - D.FallBelowFloor then",
     "\t\tor false then"),
    ("free fall ignored", CO, "\telseif died.Freefall or died.Pos == nil", "\telseif died.Pos == nil"),
    ("the void is not a fall", CO, "\telseif died.Freefall or died.Pos == nil\n\t\tor died.Pos.Y",
     "\telseif died.Freefall\n\t\tor died.Pos.Y"),
    ("Lost measured after the wrong step", CO, '\tlocal carriedBefore = numAttr(victim, "CarriedGold", 0) -- BB14',
     '\tlocal carriedBefore = 0 -- BB14'),
    ("Sack always false", CO, "Sack = ctx.HadSack == true,", "Sack = false,"),
    ("the payload goes to everyone", CO, '\tNet.Fx(victim, "KO", {', '\tNet.Fx(nil, "KO", {'),
    ("the killer's raw name", CO, 'by, name, killerFaction = "Player", publicName(killer), faction(killer)',
     'by, name, killerFaction = "Player", Util.PlayerDisplayName(killer), faction(killer)'),
    ("kaiju KO named as a monster", CO, 'elseif recent and src.Kind == "Kaiju" then', 'elseif false then'),
    ("no KO payload", CO, '\tpipelineCall("CombatService.sendKO", sendKO, victim, killer, koCtx, carriedBefore, died or {})\n', ""),
    ("RespawnIn missing", CO, "\t\tRespawnIn = Config.Player.RespawnTime })", "\t\tRespawnIn = nil })"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    monster = read(SSS / "MonsterService.luau")
    check("S.CombatService.DamagePlayer(target, rec.Def.Damage, nil, false, rec.Kind)" in monster,
          "MonsterService passes the monster kind (BB14 sourceKind)")
    kaiju = read(SSS / "KaijuService.luau")
    check('Config.Kaiju.StompPct), atk, false,\n\t\t\t\t\t\t"Kaiju")' in kaiju, "the kaiju stomp passes sourceKind \"Kaiju\"")
    combat = read(SSS / "CombatService.luau")
    died = function_block(combat, "local function onCharacterDied(")
    check("Util.GetRoot(player)" in died and died.find("Util.GetRoot(player)") < died.find("task.defer("),
          "the body's position is read when it falls (before the deferred pipeline)")
    check("Net.GameState" not in function_block(combat, "local function sendKO(") and '"KO"' in combat,
          "no new remote: the existing owner-only Net.Fx kind 'KO'")
    net = read(SHARED / "Net.luau")
    check('"KO"' not in net, "Net.Names unchanged (Fx carries the kind)")
    return count, failures


SUITE = Suite(
    mark="KO_SCREEN",
    fixture=ROOT / "tools/fixtures/ko_screen_offline.luau",
    world=ROOT / "tools/fixtures/dev2_world.luau",
    out=ROOT / "docs/art/verification_2026-10-06/offline_dev2_ko_screen_2026-10-06.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="BB14 server: CombatService.DamagePlayer(victim, amount, attacker, crit, sourceKind) records { Kind, T } per "
             "victim when no attacker (MonsterService passes the monster kind, the kaiju stomp \"Kaiju\"). After the death "
             "pipeline the victim alone gets Net.Fx 'KO' { By, Name, Faction, Lost, Sack, RespawnIn }: By = Player (a "
             "PvP killer; Name = PublicName, Faction) > Kaiju (a stomp within 3 s; the kaiju's PublicName) > Monster (a hit "
             "within Config.Death.SourceSeconds; Config.MonsterTypes name) > Fall (free fall, the body gone, or 30 below "
             "its zone's floor at the moment it fell) > Other. Lost = the pouch difference over steps 1-2 (plunder, the "
             "bounty KO share), Sack = a grudge sack was carried. The source is forgotten after each death.",
    limitations="Offline doubles as in tools/test_ranking.py (dev2_world.luau). The client DeathScreen (overlay, tips, "
                "closing on respawn) is the 게임성 개발 session's; real falls / resets in Studio are checked after the merge.",
)

if __name__ == "__main__":
    run(SUITE)
