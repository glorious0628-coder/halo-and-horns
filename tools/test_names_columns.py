"""BB37 one public name for every server-wide line (AnnounceService.PublicName) and BB12 Tab list columns, offline.

Runs the CURRENT Config, Util, AnnounceService and PvPService sources, the PlayerService leaderstats block and the
publicName helper of every announcing service (tools/fixtures/names_columns_offline.luau on tools/fixtures/dev2_kit.luau)
with the installed official Luau CLI. No Studio, network, DataStore or Roblox API calls. Mutations run on in-memory
copies of the sources only.

Spec: docs/design/beta_basics_2026-10-05.md "### BB37." and "### BB12."; SPEC A23-21 (Tab: power, level, rebirths,
fame; gold hidden), A23-24 (Neutral fame = this week's 장인 명성).
Usage: py tools/test_names_columns.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_dev2_names_columns_2026-10-06.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, between, function_block, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "ANNOUNCE_SOURCE": SSS / "AnnounceService.luau",
    "PVP_SOURCE": SSS / "PvPService.luau",
    "PLAYER_SOURCE": SSS / "PlayerService.luau",
    "GRUDGE_SOURCE": SSS / "GrudgeService.luau",
    "PROGRESSION_SOURCE": SSS / "ProgressionService.luau",
    "GOOSE_SOURCE": SSS / "GooseService.luau",
    "KAIJU_SOURCE": SSS / "KaijuService.luau",
}
HELPER_FILES = {"PvPService": "PVP_SOURCE", "GrudgeService": "GRUDGE_SOURCE", "ProgressionService": "PROGRESSION_SOURCE",
                "GooseService": "GOOSE_SOURCE", "KaijuService": "KAIJU_SOURCE"}


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = {k: sources[k] for k in ("CONFIG_SOURCE", "UTIL_SOURCE", "ANNOUNCE_SOURCE", "PVP_SOURCE")}
    player = sources["PLAYER_SOURCE"]
    keys = re.search(r"^local LEADERSTAT_KEYS = \{.*?\}\n", player, re.M | re.S)
    if not keys:
        raise ValueError("Source boundary changed: PlayerService LEADERSTAT_KEYS; update the test extractor.")
    out["LEADERSTATS_SOURCE"] = (
        "local Config, Util, addConn = ...\nlocal TAG = \"PlayerService\"\n" + keys.group(0)
        + between(player, "------------------------------------------------------------------ leaderstats",
                  "------------------------------------------------------------------ character lifecycle")
        + "\nreturn LEADERSTAT_KEYS, buildLeaderstats\n")
    for service, key in HELPER_FILES.items():
        out["HELPER_" + service] = ("local S, Util, Config = ...\n" + function_block(sources[key], "local function publicName(")
                                    + "\nreturn publicName\n")
    return out


MUTATIONS = [
    ("PublicName ignores the hidden choice", "ANNOUNCE_SOURCE", "\tif isHidden(player) then\n\t\tlocal id", "\tif false then\n\t\tlocal id"),
    ("hidden name ignores the faction", "ANNOUNCE_SOURCE",
     "return f and string.format(T.HiddenName, f.Name) or T.Someone", "return T.Someone"),
    ("None faction shows 'A member of the No Side'", "ANNOUNCE_SOURCE",
     'local f = id ~= "None" and Config.Factions[id] or nil', "local f = Config.Factions[id]"),
    ("honorific always added", "ANNOUNCE_SOURCE",
     '(honorific == true and T.Honorific or "")', "T.Honorific"),
    ("honorific never added", "ANNOUNCE_SOURCE",
     '(honorific == true and T.Honorific or "")', '""'),
    ("attribute fallback ignored before data", "ANNOUNCE_SOURCE",
     'return player:GetAttribute("HideAnnounceName") == true', "return false"),
    ("data choice ignored (attribute only)", "ANNOUNCE_SOURCE",
     "if data ~= nil then return data.HideAnnounceName == true end", ""),
    ("SetAnnounceName never marks the ranking rows", "ANNOUNCE_SOURCE",
     "pcall(ranking.MarkHideChanged, player)", "local _ = ranking"),
    ("MarkHideChanged error not caught", "ANNOUNCE_SOURCE",
     "pcall(ranking.MarkHideChanged, player)", "ranking.MarkHideChanged(player)"),
    ("Most Wanted back to the raw name", "PVP_SOURCE",
     'fmt("MostWanted", publicName(p, true),', 'fmt("MostWanted", Util.PlayerDisplayName(p),'),
    ("board wanted rows back to the raw name", "PVP_SOURCE",
     "table.insert(wanted, { P = p, Name = publicName(p), Bounty", "table.insert(wanted, { P = p, Name = Util.PlayerDisplayName(p), Bounty"),
    ("board wanted rows with honorific", "PVP_SOURCE",
     "table.insert(wanted, { P = p, Name = publicName(p), Bounty", "table.insert(wanted, { P = p, Name = publicName(p, true), Bounty"),
    ("PvP helper skips PublicName", "PVP_SOURCE",
     "\tif A and A.PublicName then\n\t\tlocal ok, name = pcall(A.PublicName, p, honorific)",
     "\tif false then\n\t\tlocal ok, name = pcall(A.PublicName, p, honorific)"),
    ("Kaiju helper drops the honorific flag", "KAIJU_SOURCE",
     "local ok, name = pcall(A.PublicName, p, honorific)", "local ok, name = pcall(A.PublicName, p)"),
    ("Goose helper has no fallback", "GOOSE_SOURCE",
     '\treturn Util.PlayerDisplayName(p) .. (honorific and Config.Announce.Text.Honorific or "")\nend',
     "\treturn nil\nend"),
    ("RebirthAnnounce adds its own honorific (doubled)", "CONFIG_SOURCE",
     'RebirthAnnounce = "%s was reborn! (Rebirth #%d)"', 'RebirthAnnounce = "%s~h was reborn! (Rebirth #%d)"'),
    ("MostWanted drops the name", "CONFIG_SOURCE",
     'MostWanted = "%s is now the Most Wanted!', 'MostWanted = "%.0sA player is now the Most Wanted!'),
    ("HiddenName without 'A member of the'", "CONFIG_SOURCE", 'HiddenName = "A member of the %s", HiddenNameEn', 'HiddenName = "%s", HiddenNameEn'),
    # BB12
    ("power column reads the level", "PLAYER_SOURCE",
     'local v = p:GetAttribute("CombatPower")', 'local v = p:GetAttribute("Level")'),
    ("power column without the formula fallback", "PLAYER_SOURCE",
     "\t\tif v == nil then\n\t\t\tv = Config.CombatPower(", "\t\tif false then\n\t\t\tv = Config.CombatPower("),
    ("Neutral fame stays 0", "PLAYER_SOURCE", '(f == "Neutral" and "WeekArtisan")', '(f == "Neutral" and nil)'),
    ("Horns fame reads Honor", "PLAYER_SOURCE", '(f == "Horns" and "Infamy")', '(f == "Horns" and "Honor")'),
    ("columns built in table order of a map", "PLAYER_SOURCE",
     "for _, id in L.Columns do\n\t\tif COLUMN[id] and not columns[id] then",
     "for id in COLUMN do\n\t\tif table.find(L.Columns, id) and not columns[id] then"),
    ("repeated column ids accepted", "PLAYER_SOURCE", "if COLUMN[id] and not columns[id] then", "if COLUMN[id] then"),
    ("CombatPower not watched", "PLAYER_SOURCE", 'local LEADERSTAT_KEYS = { "CombatPower", ', "local LEADERSTAT_KEYS = { "),
    ("WeekArtisan not watched", "PLAYER_SOURCE", '"Honor", "Infamy", "WeekArtisan", "Faction" }', '"Honor", "Infamy", "Faction" }'),
    ("gold column back in the list", "CONFIG_SOURCE",
     'Columns = { "Power", "Level", "Rebirths", "Fame" },', 'Columns = { "Power", "Level", "Gold", "Rebirths", "Fame" },'),
    ("level column first", "CONFIG_SOURCE",
     'Columns = { "Power", "Level", "Rebirths", "Fame" },', 'Columns = { "Level", "Power", "Rebirths", "Fame" },'),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    raw_names = []
    for path in sorted(SSS.glob("*.luau")):
        code = strip_comments(read(path))
        for line in code.splitlines():
            if "NotifyAll" in line and "PlayerDisplayName" in line:
                raw_names.append(f"{path.name}: {line.strip()}")
    check(not raw_names, f"BB37 acceptance: no NotifyAll line uses Util.PlayerDisplayName: {raw_names}")
    sites = {
        "PvPService.luau": [r'fmt\("MostWanted", publicName\(p, true\)', r"NotifyAll\(bountyLine\(killer, bounty\)\)",
                            r"NotifyAll\(bountyLine\(a, bounty\)\)",
                            r'"BountyAnnounceHidden" or "BountyAnnounce", publicName\(p, true\)',
                            r"wanted, \{ P = p, Name = publicName\(p\)"],
        "GrudgeService.luau": [r'fmt\("GrudgeAvengedAll", publicName\(killer, true\), publicName\(thief, true\)\)'],
        "ProgressionService.luau": [r"Config\.Text\.RebirthAnnounce, publicName\(player, true\)"],
        "GooseService.luau": [r"Config\.Text\.RareAnnounce, publicName\(p, true\)"],
        "KaijuService.luau": [r"kaijuName = publicName\(p\)"],
    }
    for name, patterns in sites.items():
        code = strip_comments(read(SSS / name))
        for pat in patterns:
            check(re.search(pat, code) is not None, f"BB37 site uses PublicName: {name} /{pat}/")
        check(code.count("local function publicName(") == 1, f"{name} has one publicName helper")
    board = strip_comments(between(read(SSS / "PvPService.luau"), "local function updateBoard()",
                                   "------------------------------------------------------------------ loops"))
    check("PlayerDisplayName" not in board, "PvPService.updateBoard never uses the raw name")
    announce = read(SSS / "AnnounceService.luau")
    check("function AnnounceService.PublicName(player, honorific)" in announce, "AnnounceService.PublicName(player, honorific) exported")
    main = read(SSS / "Main.server.luau")
    init = re.search(r"local INIT_ORDER = \{(.*?)\}", main, re.S)
    check(init is not None and '"AnnounceService"' in init.group(1), "AnnounceService stays in INIT_ORDER (the registry has it)")
    justice = read(SSS / "JusticeService.luau")
    check('SetAttribute("CombatPower"' in justice, "JusticeService sets the CombatPower attribute the power column reads")
    return count, failures


SUITE = Suite(
    mark="NAMES_COLUMNS",
    fixture=ROOT / "tools/fixtures/names_columns_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-06/offline_dev2_names_columns_2026-10-06.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="BB37: AnnounceService.PublicName(player, honorific) = Util.PlayerDisplayName (+ Config.Announce.Text.Honorific "
             "\"님\" when honorific) or, when data.HideAnnounceName (attribute before the data loads), HiddenName \"<faction> 한 명\" "
             "(Someone \"누군가\" without a faction), never with an honorific; every server-wide line goes through it: "
             "PvPService MostWanted / 2x BountyAnnounce / town board (the wanted line; the weekly rows come from RankingService.ServerTop), GrudgeService GrudgeAvengedAll, "
             "ProgressionService RebirthAnnounce, GooseService RareAnnounce, KaijuService kaiju name; the five Config.Text lines "
             "use \"%s이\" so \"OO님이\" / \"뿔 군단 한 명이\" both read right; the SetAnnounceName handler calls "
             "RankingService.MarkHideChanged (pcall, optional); setting label '알림·랭킹에 내 이름 숨기기' + 2 notes (KO/EN). "
             "BB12: Config.Leaderstats.Columns {Power, Level, Rebirths, Fame} (gold hidden, A23-21), creation order = column "
             "order, Power = the CombatPower attribute (formula fallback before JusticeService sets it), Fame = Halo Honor / "
             "Horns Infamy / Neutral WeekArtisan (A23-24) / None 0, LEADERSTAT_KEYS watches every attribute a column reads, "
             "unknown / repeated ids skipped with a warning; changing the columns is one Config line.",
    limitations="Offline doubles: Players / Instances / attributes, PlayerService (data rows, SetStat mirror), ClassService, "
                "FactionService / JusticeService / CombatService / ZoneService / KaijuService / MapBuilder stand-ins for the "
                "whole PvPService. GrudgeService / ProgressionService / GooseService / KaijuService lines are checked "
                "statically plus their extracted publicName helper. The Roblox player list UI, chat rendering and 2-client "
                "checks are not certified here (the 게임성 개발 session plays them after the merge).",
)

if __name__ == "__main__":
    run(SUITE)
