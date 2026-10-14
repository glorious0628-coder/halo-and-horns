"""The private test's numbers board (TestMetricsService) (게임성 개발 2, 2026-10-13, A23-160 ④), offline.

Contract docs/design/test_metrics_2026-10-13.md: an observer (adds data.Telemetry.Test only, never on Live). Per test round (Config.TestMetrics.Round) it sums into ONE
DataStore document (Config.StoreName(Config.TestMetrics.Store); Studio: _STUDIO): Players / New / Joins, the first screen (Intro,
Faction, Side), the minute of play new accounts reach Lv5 / Lv10 / the first dropped weapon / the first mission claim (Min), the
10-minute run (Ten), the first device (Device) and passes bought / kept on a later join (Pass). Runs the CURRENT Config, Util and
TestMetricsService on tools/fixtures/dev2_kit.luau + tools/fixtures/dev3_world.luau with tools/fixtures/test_metrics_offline.luau and
the installed official Luau CLI. Static checks: listed in Main and started before PlayerService, the signals it listens to exist at
their source, the store name goes through Config.StoreName, merged only (UpdateAsync), nothing sold or paid, no UserId / name,
the board script's reader names the same store and round. No Studio, network, DataStore or Roblox API calls.

Usage: py tools/test_test_metrics.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-13/offline_test_metrics_2026-10-13.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "METRICS_SOURCE": SSS / "TestMetricsService.luau",
}
C, TM = "CONFIG_SOURCE", "METRICS_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # --- config
    ("the board is off", C, "Config.TestMetrics = {\n\tEnabled = true,", "Config.TestMetrics = {\n\tEnabled = false,"),
    ("fresh means 10 minutes", C, "\tFreshSeconds = 120,\n", "\tFreshSeconds = 600,\n"),
    ("the run is 15 minutes", C, "\tTenMinutes = 10,\n", "\tTenMinutes = 15,\n"),
    ("the rejoin check at once", C, "\tKeptDelay = 20,\n", "\tKeptDelay = 1,\n"),
    ("no Lv10 milestone", C, 'Milestones = { "Lv5", "Lv10", "Weapon", "Claim" },', 'Milestones = { "Lv5", "Weapon", "Claim" },'),
    # --- joins
    ("a rejoin is a new player", TM, "\tif num(rec.J) == 0 then\n\t\tbump(d, \"Players\")", "\tif true then\n\t\tbump(d, \"Players\")"),
    ("every account is new", TM, "\t\trec.N = fresh(player, data)\n", "\t\trec.N = true\n"),
    ("joins are not counted", TM, "\tbump(d, \"Joins\")\n", ""),
    ("the intro does not matter for fresh", TM, "\treturn data.IntroSeen ~= true and num(data.Level, 1) <= 1",
     "\treturn num(data.Level, 1) <= 1"),
    ("kills do not matter for fresh", TM, " and num(data.TotalKills) <= 0\n", "\n"),
    ("an old round is kept", TM, "if type(rec) ~= \"table\" or rec.R ~= round then", "if type(rec) ~= \"table\" then"),
    # --- first screen
    ("the intro counts twice", TM, "\tif not rec.I and attr(player, data, \"IntroSeen\") == true then",
     "\tif attr(player, data, \"IntroSeen\") == true then"),
    ("None is a side", TM, "Sides = { Halo = true, Horns = true, Neutral = true },", "Sides = { Halo = true, Horns = true, Neutral = true, None = true },"),
    ("a side change counts", TM, "\tif not rec.S and type(side) == \"string\" and X.Sides[side] then",
     "\tif type(side) == \"string\" and X.Sides[side] then"),
    ("veterans count", TM, "\tif rec.N ~= true then return end\n\tlocal d = X.Delta", "\tlocal d = X.Delta"),
    # --- milestones
    ("Lv5 at Lv4", TM, "return num(attr(p, d, \"Level\"), 1) >= 5 end", "return num(attr(p, d, \"Level\"), 1) >= 4 end"),
    ("A23-188: the T1 gift is not the first weapon", TM, "return num(attr(p, d, \"WeaponOwnedMask\")) >= 1 end", "return num(attr(p, d, \"WeaponOwnedMask\")) >= 2 end"),
    ("any step is the claim", TM, "return num(attr(p, d, \"TutorialStep\")) == 99 end", "return num(attr(p, d, \"TutorialStep\")) >= 1 end"),
    ("a milestone counts every time", TM, "if reached and rec.M[m] == nil and reached(player, data) then", "if reached and reached(player, data) then"),
    ("minutes are seconds", TM, "math.floor(math.max(0, sec) / 60)", "math.floor(math.max(0, sec))"),
    ("no minute cap", TM, "return math.clamp(math.floor(math.max(0, sec) / 60), 0, math.max(1, math.floor(num(M.MaxMinute, 60))))",
     "return math.max(0, math.floor(math.max(0, sec) / 60))"),
    ("minute 10 is inside the run", TM, "and mm.Lv5 < ten and mm.Weapon < ten and mm.Claim < ten then",
     "and mm.Lv5 <= ten and mm.Weapon <= ten and mm.Claim <= ten then"),
    ("the run without the claim", TM, "\tif not rec.T and mm.Lv5 ~= nil and mm.Weapon ~= nil and mm.Claim ~= nil",
     "\tif not rec.T and mm.Lv5 ~= nil and mm.Weapon ~= nil and (mm.Claim ~= nil or true)"),
    ("the run counts twice", TM, "\tif not rec.T and mm.Lv5", "\tif mm.Lv5"),
    ("no scan at the join", TM, "\t\tend))\n\tend\n\tscan(player)\nend", "\t\tend))\n\tend\nend"),
    ("no watcher on the level", TM, 'Watched = { "IntroSeen", "Faction", "Level", "WeaponOwnedMask", "TutorialStep" },',
     'Watched = { "IntroSeen", "Faction", "WeaponOwnedMask", "TutorialStep" },'),
    # --- passes
    ("an unknown pass counts", TM, "\tif type(Config.GamePasses) == \"table\" and Config.GamePasses[key] then return key end",
     "\tif true then return key end"),
    ("the same join is a rejoin", TM, "if passKey(key) and not rec.K[key] and rec.J > num(at) then", "if passKey(key) and not rec.K[key] and rec.J >= num(at) then"),
    ("the rejoin counted every join", TM, "\tif rec.K[key] then return end\n\trec.K[key] = true\n", "\trec.K[key] = true\n"),
    ("kept without asking", TM, "\tif ok and answer == true then\n\t\tbump(p, \"Kept\")", "\tif true then\n\t\tbump(p, \"Kept\")"),
    ("no answer counted as kept", TM, "\tif ok and answer == true then\n", "\tif ok and answer ~= false then\n"),
    ("the saved answer read", TM, "type(mon.PassAnswer) == \"function\" then ok, answer = pcall(mon.PassAnswer, player, key)",
     "type(mon.HasPass) == \"function\" then ok, answer = pcall(mon.HasPass, player, key)"),
    ("Live too", TM, "\tif type(Config.EnvName) == \"function\" and Config.EnvName() == \"Live\" then return end", ""),
    ("a gone player is checked", TM, "local function checkKept(player, key)\n\tif player.Parent == nil then return end\n",
     "local function checkKept(player, key)\n"),
    ("the purchase join moves", TM, "\tif rec.P[key] == nil then rec.P[key] = math.max(1, math.floor(num(rec.J))) end",
     "\trec.P[key] = math.max(1, math.floor(num(rec.J)))"),
    ("the check runs at once", TM, "task.delay(math.max(1, num(M.KeptDelay, 20)), function()", "task.delay(0, function()"),
    # --- devices
    ("any device", TM, "\tif not table.find(devices, dev) then return end\n", ""),
    ("every sample", TM, "if rec.N ~= true or rec.D or type(dev) ~= \"string\" then return end", "if rec.N ~= true or type(dev) ~= \"string\" then return end"),
    # --- the document
    ("Studio writes the live store", TM, "\t\tif RunService:IsStudio() then name ..= \"_STUDIO\" end\n", ""),
    ("the key is not the round", TM, "pcall(st.UpdateAsync, st, tostring(M.Round or \"PT1\"), function(old)", "pcall(st.UpdateAsync, st, \"All\", function(old)"),
    ("the old document is replaced", TM, "\tif type(old) == \"table\" then sumInto(out, old) end\n", ""),
    ("a failed write loses the sums", TM, "\tlocal back = {}\n\tsumInto(back, mine)\n\tsumInto(back, X.Delta)\n\tX.Delta = back\n", ""),
    ("the memory keeps saved sums", TM, "\tX.Delta = {} -- what is added while the write waits", "\t-- what is added while the write waits"),
    ("no close flush", TM, "\tgame:BindToClose(function()\n\t\tpcall(TestMetricsService.Flush)\n\tend)\n", ""),
    ("no flush loop", TM, "\t\t\tpcall(TestMetricsService.Flush)\n\t\tend\n", "\t\tend\n"),
    ("strings are summed", TM, "\t\tif type(v) == \"number\" and v == v then", "\t\tif v ~= nil and type(v) ~= \"table\" then"),
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
    check(init_list.count("TestMetricsService") == 1 and start_list.count("TestMetricsService") == 1, "TestMetricsService is in both lists once")
    check("TestMetricsService" in start_list and start_list.index("TestMetricsService") < start_list.index("PlayerService")
          and start_list[-1] == "PlayerService", "TestMetricsService starts before PlayerService (it listens to PlayerReady)")
    check(sorted(init_list) == sorted(start_list), "every service is in both lists")
    code = strip_comments(read(SSS / "TestMetricsService.luau"))
    check("Config.StoreName" in code, "the store name goes through Config.StoreName (Beta / Live get their own)")
    check(code.count("GetDataStore") == 1, "one DataStore handle")
    check(code.count("UpdateAsync") == 1 and "SetAsync" not in code and "RemoveAsync" not in code, "the document is only merged (one UpdateAsync)")
    check("UserId" not in code and "player.Name" not in code and "DisplayName" not in code, "no UserId, no player name")
    check("MarketplaceService" not in code and "AddBankGold" not in code and "AddStat" not in code and "SetStat" not in code
          and "GrantItem" not in code and "SetAttribute" not in code, "nothing sold, paid or changed (adds data.Telemetry.Test only)")
    check(not re.search(r"[가-힣]", code), "no Korean outside comments")
    for service, signal in (("PlayerService", "PlayerReady"), ("PlayerService", "PlayerLeaving"),
                            ("MonetizationService", "PassBought"), ("TelemetryService", "ClientMetric")):
        check(f'connect("{service}", "{signal}"' in code, f"listens to {service}.{signal}")
    mon = read(SSS / "MonetizationService.luau")
    check("MonetizationService.PassBought = Util.Signal.new()" in mon and "MonetizationService.PassBought:Fire(player, p.Key)" in mon,
          "MonetizationService.PassBought(player, key) exists and fires with the pass key")
    check("function MonetizationService.HasPass(player, key)" in mon, "MonetizationService.HasPass(player, key) exists")
    tel = read(SSS / "TelemetryService.luau")
    check("TelemetryService.ClientMetric = T.ClientMetric" in tel, "TelemetryService.ClientMetric exists")
    ps = read(SSS / "PlayerService.luau")
    check("PlayerService.PlayerReady" in ps and "PlayerService.PlayerLeaving" in ps, "PlayerService.PlayerReady / PlayerLeaving exist")
    cfg = strip_comments(read(SHARED / "Config.luau"))
    check(cfg.count("Config.TestMetrics = {") == 1, "Config.TestMetrics exists once")
    for key in ("IntroSeen", "Faction", "Level", "WeaponOwnedMask", "TutorialStep", "PlaytimeSeconds"):
        mirrored = re.search(r"Mirrored = \{(.*?)\n\t\}", cfg, re.S)
        check(mirrored is not None and f'"{key}"' in mirrored.group(1), f"{key} is a mirrored attribute (the watchers read it)")
    board = ROOT / "tools/test_metrics_board.py"
    text = board.read_text(encoding="utf-8") if board.exists() else ""
    check("Config.TestMetrics" in text and "Config.StoreName" in text and "_STUDIO" in text,
          "tools/test_metrics_board.py reads Config.TestMetrics' store (Config.StoreName; --studio-copy = _STUDIO)")
    return count, failures


SUITE = Suite(
    mark="TEST_METRICS",
    fixture=ROOT / "tools/fixtures/test_metrics_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-13/offline_test_metrics_2026-10-13.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="TestMetricsService: an observer (adds data.Telemetry.Test only), on while Config.TestMetrics.Enabled and never on Live. Per round one document in "
             "Config.StoreName('HaloHorns_TestMetrics_v1') (Studio: _STUDIO), key = Config.TestMetrics.Round: Players (accounts "
             "seen this round), New (fresh saves: no intro, Lv1, no kill, under FreshSeconds), Joins, Intro / Faction / Side "
             "(new accounts' first screen), Min[Lv5|Lv10|Weapon|Claim][minute of play] (once per account; Weapon = a tier 2+ "
             "bit, Claim = TutorialStep 99; minute capped at MaxMinute), Ten (Lv5 + Weapon + Claim all before minute "
             "TenMinutes), Device (the first Perf sample's device), Pass[key] = { Bought, Back (a later join, KeptDelay s after "
             "it), Kept (HasPass true then) }. The account record is data.Telemetry.Test (additive; another round's starts over). "
             "Flush every FlushSeconds (x0.5..1.5) and at the close: UpdateAsync merge (numbers added); a failed write keeps the sums.",
    limitations="Real DataStore limits are not simulated (one UpdateAsync a minute per server is far under them). The Studio "
                "reader in tools/test_metrics_board.py is checked by source only (it needs a Studio with API access).",
)

if __name__ == "__main__":
    run(SUITE)
