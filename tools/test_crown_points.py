"""Crown points on the new scale + Honor / Infamy from hunting (게임성 개발 2, 2026-10-13; gameplay_plan 2-A #4 / #5, A23-135 / A23-137), offline.

WarService: a kill gives kill units (Config.War.MonsterPoints, golden GoldenPoints = 5); KillsPerPoint (100) units = one WHOLE
personal point (saved in data.CrownUnits over rounds and sessions, dropped on a side switch), the side pool takes the fraction
at once (CR-M18 share); PvP KO = 2 + 0.5 a star fair-rounded to a whole number, at most PvPKOMaxPerRound (3) rewarded KOs a
killer (UserId) a round, rejoining does not reset it; events (goose 30, kaiju 30) pool only; ChestMinPoints 1, SiegeTarget
1.5; the per-capita scores shown with two decimals and the winner decided on the shown values; WarService.PersonalAdded(player,
n, source) for every whole personal gain. StoryQuestService: a crown step (Type WarPoints) counts the kill units (1, golden 5),
not whole points; M2_1 15, GW4 100 (final review 10/13: a 1-whole-point step stalled the main line). HuntFameService: kills in
the player's own level zone or a harder one (Config.HuntFame.ZoneLevel for the fields without a level gate), 100 units =
Honor / Infamy +1 (PlayerService.GrantFame ctx Hunt), saved in data.HuntFame; Neutral / personal / practice / field-boss free
riders: nothing. Runs the CURRENT Config, Util, WarService, HuntFameService and
StoryQuestService on tools/fixtures/dev2_kit.luau + tools/fixtures/dev3_world.luau with tools/fixtures/crown_points_offline.luau.

Usage: py tools/test_crown_points.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-13/offline_crown_points_2026-10-13.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "WAR_SOURCE": SSS / "WarService.luau",
    "HUNT_SOURCE": SSS / "HuntFameService.luau",
    "STORY_SOURCE": SSS / "StoryQuestService.luau",
}
C, W, H, ST = "CONFIG_SOURCE", "WAR_SOURCE", "HUNT_SOURCE", "STORY_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # --- Config
    ("1 kill = 1 point again", C, "\tKillsPerPoint = 100, -- A23-135", "\tKillsPerPoint = 1, -- A23-135"),
    ("PvP KO 20 again", C, "\tPvPKOPoints = 2, -- A23-137: was 20", "\tPvPKOPoints = 20, -- A23-137: was 20"),
    ("no PvP cap", C, "\tPvPKOMaxPerRound = 3,", "\tPvPKOMaxPerRound = 99,"),
    ("chest at 30 again", C, "\tChestMinPoints = 1,", "\tChestMinPoints = 30,"),
    ("siege at 150 again", C, "\tSiegeTarget = 1.5,", "\tSiegeTarget = 150,"),
    ("kaiju 150 again", C, "HornsWarPoints = 30, -- war points", "HornsWarPoints = 150, -- war points"),
    ("M2_1 needs 1 whole point", C, 'Obj = { Type = "WarPoints", Count = 15 },', 'Obj = { Type = "WarPoints", Count = 1 },'),
    ("units not saved by default", C, "Config.Data.Defaults.CrownUnits = 0\n", ""),
    ("Crystal Woods at its MinLevel", C, "CoralCoast = 8, CrystalWoods = 14,", "CoralCoast = 8, CrystalWoods = 1,"),
    ("hunt fame off", C, "Config.HuntFame = {\n\tEnabled = true,", "Config.HuntFame = {\n\tEnabled = false,"),
    # --- WarService
    ("kills go to AddPoints (a point a kill)", W, "WarService.AddKill(player, info.WarPoints, info.WarShare)",
     "WarService.AddPoints(player, info.WarPoints, info.WarShare)"),
    ("the pool takes whole units", W, "points[f] += (isValidAmount(poolU) and math.min(poolU, u) or u) / per",
     "points[f] += (isValidAmount(poolU) and math.min(poolU, u) or u)"),
    ("the pool ignores the share", W, "points[f] += (isValidAmount(poolU) and math.min(poolU, u) or u) / per", "points[f] += u / per"),
    ("the units never carry", W, "\tdata.CrownUnits = have - whole * per\n", "\tdata.CrownUnits = 0\n"),
    ("the units are not read back", W, "local have = savedUnits(data) + u", "local have = u"),
    ("a NaN save poisons the units", W, "return (isValidAmount(v)) and v or 0", "return v or 0"),
    ("no PersonalAdded for kills", W, "\t\tWarService.PersonalAdded:Fire(player, whole, \"Hunt\")\n", ""),
    ("no PersonalAdded for PvP", W, "\tWarService.PersonalAdded:Fire(player, n, type(source) == \"string\" and source or \"Other\")\n", ""),
    ("PvP is not named", W, "WarService.AddPoints(killer, points, nil, \"PvP\")", "WarService.AddPoints(killer, points)"),
    ("the PvP cap never resets", W, "\ttable.clear(hunt.KOs) -- A23-137", "\t-- A23-137"),
    ("the PvP cap by Player again", W, "local kos = hunt.KOs[killer.UserId] or 0", "local kos = hunt.KOs[killer] or 0"),
    ("PvP 2.5 stays 2.5", W, "\t\t\t\tif S.PvPService.ScalePoints then\n\t\t\t\t\tpoints = S.PvPService.ScalePoints(points, bold)\n"
     "\t\t\t\telse\n\t\t\t\t\tpoints = math.floor(points * bold + 0.5)\n\t\t\t\tend\n", "\t\t\t\tpoints = points * bold\n"),
    ("the winner on the raw scores", W, "local haloScore = round2(points.Halo / math.max(1, halo))", "local haloScore = points.Halo / math.max(1, halo)"),
    ("the PvP cap counts a KO that scored nothing", W,
     "\t\t\t\tif points > 0 and WarService.AddPoints(killer, points, nil, \"PvP\") then hunt.KOs[killer.UserId] = kos + 1 end\n",
     "\t\t\t\thunt.KOs[killer.UserId] = kos + 1\n\t\t\t\tif points > 0 then WarService.AddPoints(killer, points, nil, \"PvP\") end\n"),
    ("AddPoints answers false after adding", W, "\tWarService.PersonalAdded:Fire(player, n, type(source) == \"string\" and source or \"Other\")\n\treturn true\n",
     "\tWarService.PersonalAdded:Fire(player, n, type(source) == \"string\" and source or \"Other\")\n\treturn false\n"),
    ("the PvP cap is off", W, "\t\t\t\tif kos >= (tonumber(Config.War.PvPKOMaxPerRound) or 3) then return end\n", ""),
    ("a side switch keeps the units", W, "\t\t\t\tif type(data) == \"table\" then data.CrownUnits = 0 end\n", ""),
    ("Neutral scores kills", W, "\tif not WAR_FACTIONS[f] then return end\n\tlocal data = S.PlayerService.GetData(player)",
     "\tlocal data = S.PlayerService.GetData(player)"),
    # --- StoryQuestService
    ("crown steps count 1 a kill (golden 1)", ST, "if t == \"WarPoints\" then return math.max(0, num(info.WarPoints)) end",
     "if t == \"WarPoints\" then return 1 end"),
    ("crown steps can go negative", ST, "if t == \"WarPoints\" then return math.max(0, num(info.WarPoints)) end",
     "if t == \"WarPoints\" then return num(info.WarPoints) end"),
    ("crown steps count nothing", ST, "if t == \"WarPoints\" then return math.max(0, num(info.WarPoints)) end", ""),
    # --- HuntFameService
    ("every zone counts", H, "\treturn own ~= nil and here >= own\n", "\treturn true\n"),
    ("only the own zone counts", H, "\treturn own ~= nil and here >= own\n", "\treturn own ~= nil and here == own\n"),
    ("golden counts 1", H, "(info.Golden == true and num(H.GoldenUnits, 5) or num(H.Units, 1))", "num(H.Units, 1)"),
    ("Neutral gets fame", H, "local STAT = { Halo = \"Honor\", Horns = \"Infamy\" }", "local STAT = { Halo = \"Honor\", Horns = \"Infamy\", Neutral = \"Honor\" }"),
    ("personal monsters count", H, "info.Personal == true or info.Practice == true or info.Minor == true then return end",
     "info.Practice == true or info.Minor == true then return end"),
    ("free riders count", H, " or info.Minor == true then return end", " then return end"),
    ("no ZoneLevel table", H, "local lv = type(H.ZoneLevel) == \"table\" and H.ZoneLevel[zoneId] or nil", "local lv = nil"),
    ("the count is not saved", H, "\tdata.HuntFame = have - whole * per\n", "\tdata.HuntFame = 0\n"),
    ("fame on the PvP boards", H, "{ Hunt = true }", "{ PvP = true, Fair = true }"),
    ("no line", H, "\tif type(line) == \"string\" then Net.Notify(player, string.format(line, points), \"reward\", nil, \"RankUp\") end\n", ""),
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
    check(init_list.count("HuntFameService") == 1 and start_list.count("HuntFameService") == 1, "HuntFameService is in both lists once")
    check("HuntFameService" in start_list and start_list.index("HuntFameService") < start_list.index("PlayerService"),
          "HuntFameService starts before PlayerService")
    check(sorted(init_list) == sorted(start_list), "every service is in both lists")
    hunt = strip_comments(read(SSS / "HuntFameService.luau"))
    check("S.PlayerService.GrantFame(player, stat, points, { Hunt = true })" in hunt, "fame goes through PlayerService.GrantFame (ctx Hunt)")
    check("AddStat" not in hunt and "SetStat" not in hunt and "AddBankGold" not in hunt, "HuntFameService never writes stats itself or pays gold")
    rank = read(SSS / "RankingService.luau")
    body = rank[rank.find("function RankingService.CreditFame"):]
    body = body[:body.find("\nend\n")]
    check("ctx.PvP == true and ctx.Fair == true" in body and "Hunt" not in body, "RankingService.CreditFame scores PvP only (hunting fame on no board)")
    war = strip_comments(read(SSS / "WarService.luau"))
    check(war.count("WarService.PersonalAdded:Fire(") == 2, "PersonalAdded fires in AddPoints and AddKill only")
    boss = strip_comments(read(SSS / "FieldBossService.luau"))
    check("pcall(S.WarService.AddPoints, player, war, war / n)" in boss, "a field boss's War still goes through AddPoints (whole points)")
    story = strip_comments(read(SSS / "StoryQuestService.luau"))
    check("PersonalAdded" not in story and 'Kind = "War"' not in story,
          "StoryQuestService counts kill units for crown steps, not PersonalAdded (final review 10/13)")
    check(war.count("hunt.Units") == 0 and "data.CrownUnits" in war, "the kill units live in the save (data.CrownUnits), not in memory")
    ret = strip_comments(read(SSS / "ReturnService.luau"))
    check("Config.War.ChestMinPoints" in ret, "ReturnService's war card still reads ChestMinPoints (whole personal points)")
    hud = read(ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau")
    check('TXT.MyWar' not in hud and 'MyWar =' not in hud, "A23-130: no 'My pts' under the war bar (my points are in the war window)")
    check('return string.format("%g", math.floor(v * 100 + 0.5) / 100)' in hud, "the HUD shows the war scores with two decimals")
    cfg = read(SHARED / "Config.luau")
    check('"Knights earn Honor and the Horn Legion earns Mischief, from fair fights, story choices and hunting' in cfg,
          "the Honor help line names hunting")
    return count, failures


SUITE = Suite(
    mark="CROWN",
    fixture=ROOT / "tools/fixtures/crown_points_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-13/offline_crown_points_2026-10-13.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract=__doc__.split("Usage:")[0].strip(),
    limitations="The sky code runs on doubles and is not checked here (test_day_cycle / test_lighting_depth). Real players' kill "
                "rates decide whether 1 point a chest and 1.5 a head stay right (the 10/17 and 11/7 test logs).",
)

if __name__ == "__main__":
    run(SUITE)
