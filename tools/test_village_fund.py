"""The village fund (VillageFundService) (게임성 개발 2, 2026-10-14, A23-178 B), offline.

Contract docs/design/village_fund_server_2026-10-14.md: a Halo child gives Config.VillageFund.Step gold at the Halo town fountain
(Horns: no spot until its town is rebuilt; Neutral / no side: nothing) -> Honor / Infamy +Points through PlayerService.GrantFame
(ctx Fund), at most PerDay gifts a KST day (Config.DayIndex); the side's weekly sum (every server) is merged by adding into one
DataStore document per week and lights the town (looks only). Runs the CURRENT Config, Util and VillageFundService on
tools/fixtures/dev2_kit.luau + tools/fixtures/dev3_world.luau with tools/fixtures/village_fund_offline.luau and the installed
official Luau CLI. Static checks: listed in Main (both lists, after SwitchService), the remotes in Net, the GameState defaults,
the store through Config.StoreName and only merged, the gold only through SpendGold, the score only through GrantFame ctx Fund,
the day through Config.DayIndex and the week through Config.WeekIndex. No Studio, network, DataStore or Roblox API calls.

Usage: py tools/test_village_fund.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-14/offline_village_fund_2026-10-14.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "FUND_SOURCE": SSS / "VillageFundService.luau",
}
C, F = "CONFIG_SOURCE", "FUND_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # --- config
    ("the fund is off", C, "Config.VillageFund = {\n\tEnabled = true,", "Config.VillageFund = {\n\tEnabled = false,"),
    ("4 a day", C, "\tPerDay = 3,\n\tPoints = 1,", "\tPerDay = 4,\n\tPoints = 1,"),
    ("a gift is 100", C, "\tStep = 1000,\n\tPerDay = 3,", "\tStep = 100,\n\tPerDay = 3,"),
    ("Horns open before its town", C, "\t\t-- Horns: off until the Horns town is rebuilt",
     "\t\tHorns = { Pos = Vector3.new(22, 10, -590), Radius = 16, Zone = \"HornsTown\" },\n\t\t-- Horns: off until the Horns town is rebuilt"),
    ("Horns scores Honor", C, "Stat = { Halo = \"Honor\", Horns = \"Infamy\" },", "Stat = { Halo = \"Honor\", Horns = \"Honor\" },"),
    # --- the gift
    ("no rate limit", F, "\tif not Util.RateLimit(player, \"FundGive\",", "\tif false and not Util.RateLimit(player, \"FundGive\","),
    ("not ready is fine", F, "\tif not S.PlayerService.IsReady(player) then return nil end\n", ""),
    ("anywhere is near", F, "\treturn dx * dx + dz * dz <= r * r\n", "\treturn true\n"),
    ("the dead can give", F, "\tif not hum or num(hum.Health) <= 0 then return false end\n", "\tif not hum then return false end\n"),
    ("height counts", F, "local dx, dz = num(p.X) - num(c.X), num(p.Z) - num(c.Z)", "local dx, dz = num(p.Y) - num(c.Y), num(p.Z) - num(c.Z)"),
    ("the switch is ignored", F, "\tif not switchOn() then\n\t\tnotify(player, TXT.Closed", "\tif false then\n\t\tnotify(player, TXT.Closed"),
    ("a failing switchboard closes", F, "\treturn not ok or value ~= false\n", "\treturn ok and value ~= false\n"),
    ("no day limit", F, "\tif count >= perDay() then\n\t\tnotify(player, type(TXT.Full)", "\tif false then\n\t\tnotify(player, type(TXT.Full)"),
    ("yesterday's count stays", F, "\tif math.floor(num(data.FundDay)) ~= day then return 0 end\n", ""),
    ("free gifts", F, "\tif S.ProgressionService.SpendGold(player, n, \"Fund\") ~= true then",
     "\tif (S.ProgressionService.SpendGold(player, n, \"Fund\") and false) ~= false then"),
    ("the count overwritten", F, "\tdata.FundToday = count + 1\n", "\tdata.FundToday = 1\n"),
    ("the total overwritten", F, "\tdata.FundGiven = math.max(0, num(data.FundGiven)) + n\n", "\tdata.FundGiven = n\n"),
    ("the day not saved", F, "\tdata.FundDay = day\n", ""),
    ("the fame on the boards", F, "{ Fund = true })", "{ PvP = true, Fair = true })"),
    ("no fame", F, "\t\tlocal ok, err = pcall(S.PlayerService.GrantFame, player, stat, points, { Fund = true })\n",
     "\t\tlocal ok, err = true, nil\n"),
    ("the week's sum not added", F, "\taddPending(side, n)\n", ""),
    ("no card after the gift", F, "\tpublish()\n\topen(player)\nend", "\tpublish()\nend"),
    ("the other side's prompt opens", F, "\tif not data or data.Faction ~= side or not allowed(player, data) then return end",
     "\tif not data or not allowed(player, data) then return end"),
    # --- the week
    ("the old document is replaced", F, "\treturn { V = 1, Halo = a.Halo + b.Halo, Horns = a.Horns + b.Horns }",
     "\treturn { V = 1, Halo = b.Halo, Horns = b.Horns }"),
    ("a failed write loses the gifts", F, "\t\t\tX.Pending[wk] = back\n", ""),
    ("one key for every week", F, "\treturn \"W\" .. tostring(wk)\n", "\treturn \"All\"\n"),
    ("the pending week moves", F, "\tlocal wk = week()\n\tlocal p = X.Pending[wk] or {}", "\tlocal wk = 0\n\tlocal p = X.Pending[wk] or {}"),
    ("last week's stored sum shows", F, "\tlocal stored = X.Stored.Week == wk and num(X.Stored[side]) or 0",
     "\tlocal stored = num(X.Stored[side])"),
    ("the pending not shown", F, "\treturn math.max(0, stored + (pend and num(pend[side]) or 0))", "\treturn math.max(0, stored)"),
    ("Studio writes the live store", F, "\t\tif RunService:IsStudio() then name ..= \"_STUDIO\" end\n", ""),
    ("no close flush", F, "\t\tend\n\t\tpcall(VillageFundService.Flush)\n\tend)\n", "\t\tend\n\tend)\n"),
    ("no flush loop", F, "\t\t\tpcall(VillageFundService.Flush)\n\t\tend\n", "\t\tend\n"),
    ("no read loop", F, "\t\t\tpcall(VillageFundService.Read)\n", ""),
    # --- the lights
    ("fireworks at the lantern goal", F, "\tif sum >= num(g.Fireworks, math.huge) then return 2 end",
     "\tif sum >= num(g.Lanterns, math.huge) then return 2 end"),
    ("the line twice", F, "\t\t\tX.Said[key] = level\n", ""),
    ("old levels announced", F, "\t\t\tX.Said[wk .. \":\" .. side] = VillageFundService.LevelOf(VillageFundService.SumOf(side))\n", ""),
    ("the line everywhere", F, "\t\t\t\tif okZ and zone == spot.Zone then notify", "\t\t\t\tif okZ then notify"),
    ("no prompt for the side", F, "\t\t\tX.Prompts[prompt] = side\n", ""),
    # review 10/14
    ("the model is ignored", F, "\t\tif spot and type(spot.Model) == \"string\" and not X.Found[side] then",
     "\t\tif false then"),
    ("the prompt stays at the fallback", F, "\t\t\t\tif part then part.Position = cf.Position + Vector3.new(0, num(spot.Lift, 3), 0) end\n", ""),
    ("the gifts stay at the fallback", F, "\t\t\t\tX.Where[side] = cf.Position\n", ""),
    ("no search after the start", F, "\t\tpcall(resolveSpots) -- a fountain built after the start is picked up here\n", ""),
    ("a failed read is a base", F, "\tlocal okRead = st == nil\n", "\tlocal okRead = true\n"),
    ("lines before the first read", F, "\t\tif X.Base[wk] and spot and level > num(X.Said[key]) then",
     "\t\tif spot and level > num(X.Said[key]) then"),
    ("the close does not wait", F, "\t\twhile X.Writing > 0 and os.clock() - t0 < num(V.CloseWait, 20) do\n",
     "\t\twhile false do\n"),
    ("a running write not counted", F, "\tX.Writing += 1\n", ""),
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
    check(init_list.count("VillageFundService") == 1 and start_list.count("VillageFundService") == 1,
          "VillageFundService is in both lists once")
    check("VillageFundService" in start_list and "SwitchService" in start_list
          and start_list.index("SwitchService") < start_list.index("VillageFundService") < start_list.index("PlayerService"),
          "VillageFundService starts after SwitchService, before PlayerService")
    check(sorted(init_list) == sorted(start_list), "every service is in both lists")
    net = read(SHARED / "Net.luau")
    names_block = re.search(r"Net\.Names = \{(.*?)\n\}", net, re.S)
    listed = names.findall(strip_comments(names_block.group(1))) if names_block else []
    check(listed.count("FundGive") == 1 and listed.count("FundOpen") == 1, "Net: FundGive and FundOpen listed once")
    gs = re.search(r"Net\.GameStateDefaults = \{(.*?)\n\}", net, re.S)
    gsd = gs.group(1) if gs else ""
    check(all(f"{k} = 0" in gsd for k in ("FundWeek", "FundHalo", "FundHorns", "FundLevelHalo", "FundLevelHorns")),
          "GameState defaults FundWeek / FundHalo / FundHorns / FundLevelHalo / FundLevelHorns = 0")
    code = strip_comments(read(SSS / "VillageFundService.luau"))
    check("Config.StoreName" in code and code.count("GetDataStore") == 1, "one store, through Config.StoreName")
    check(code.count("UpdateAsync") == 1 and "SetAsync" not in code and "RemoveAsync" not in code and "IncrementAsync" not in code,
          "the week's document is only merged (one UpdateAsync)")
    check(code.count("SpendGold(") == 1 and "AddBankGold" not in code and "AddCarriedGold" not in code
          and "SetStat" not in code and "AddStat" not in code, "gold only through SpendGold; no stat written directly")
    check(code.count("GrantFame") == 1 and "{ Fund = true }" in code and "PvP" not in code and "RankPoints" not in code,
          "the score only through GrantFame ctx Fund (never the boards)")
    check("Config.DayIndex(os.time())" in code and "Config.WeekIndex(os.time())" in code,
          "the day = Config.DayIndex (the attendance day), the week = Config.WeekIndex")
    check("MarketplaceService" not in code and "Robux" not in code, "nothing sold")
    check(not re.search(r"[가-힣]", code), "no Korean outside comments")
    give = code[code.find("function VillageFundService.Give("):code.find("local function placePrompts(")]
    check(give.find("SpendGold(") < give.find("data.FundToday = count + 1") < give.find("GrantFame"),
          "paid first, then the record, then the score")
    check("task.wait" not in give, "no yield inside a gift")
    att = strip_comments(read(SSS / "AttendanceService.luau"))
    check("Config.DayIndex(os.time())" in att, "AttendanceService counts the same KST day (Config.DayIndex)")
    ps = read(SSS / "PlayerService.luau")
    check("function PlayerService.GrantFame(player, stat, n, ctx)" in ps and "function PlayerService.GetReadyPlayers()" in ps,
          "PlayerService.GrantFame / GetReadyPlayers exist")
    prog = read(SSS / "ProgressionService.luau")
    check("function M.SpendGold(player, amount, reason)" in prog and "function M.GetTotalGold(player)" in prog,
          "ProgressionService.SpendGold(player, amount, reason) / GetTotalGold exist")
    sw = read(SSS / "SwitchService.luau")
    check("function SwitchService.On(key)" in sw, "SwitchService.On exists")
    cfg = strip_comments(read(SHARED / "Config.luau"))
    check(cfg.count("Config.VillageFund = {") == 1, "Config.VillageFund exists once")
    return count, failures


SUITE = Suite(
    mark="VILLAGE_FUND",
    fixture=ROOT / "tools/fixtures/village_fund_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-14/offline_village_fund_2026-10-14.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="VillageFundService (A23-178): one invisible part + ProximityPrompt 'FundPrompt' per Spot (Halo now; Horns nil until its "
             "town is rebuilt). c->s FundGive (no arguments): ready, own side's Spot, alive, within Radius (flat), 1 s rate, switch "
             "VillageFund on, under PerDay today (Config.DayIndex), SpendGold(Step, 'Fund') -> FundDay / FundToday / FundGiven, "
             "GrantFame(stat, Points, { Fund = true }), the week's pending sum, the Done line, FundOpen. The week's document "
             "(Config.StoreName('HaloHorns_VillageFund_v1'), key W<week>) is merged by adding every FlushSeconds and at the close; a "
             "failed write keeps the gifts; ReadSeconds re-reads; GameState FundWeek / FundHalo / FundHorns / FundLevel*; a level "
             "reached after the first read of the week = one line to that town.",
    limitations="The client card, the town lanterns and the fireworks are 게임성 개발 1's (contract §8) and not tested here. Real "
                "DataStore limits are not simulated (one UpdateAsync a minute per server and week key).",
)

if __name__ == "__main__":
    run(SUITE)
