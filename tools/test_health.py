"""The hourly health report (HealthService) (게임성 개발 3, 2026-10-09), offline.

system_review_round1 더할 것 9 / 검수 2026-10-09 (contract docs/design/health_report_server_2026-10-09.md): per UTC hour, what the game
does - gold in / out per source, XP per level band, the goose's wins and pay, plunder amounts, pass view -> prompt -> bought,
player-minutes - summed in memory, merged into ONE DataStore document per hour by every server (UpdateAsync), read in Studio with
DebugCommand('Health'), with alert lines. Runs the CURRENT Config, Util, HealthService and ProgressionService on
tools/fixtures/dev2_kit.luau + tools/fixtures/dev3_world.luau with tools/fixtures/health_offline.luau and the installed official
Luau CLI (the other services and the DataStore are doubles). Static checks: the services are listed and start before PlayerService,
the signals HealthService listens to exist at their source (ProgressionService.XPEarned after the level-up, GooseService.GooseRewarded in
rewardPlayer), every DataStore name goes through Config.StoreName, nothing sold or paid, no UserId. No Studio, network, DataStore or
Roblox API calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_health.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-09/offline_dev3_health_2026-10-09.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "HEALTH_SOURCE": SSS / "HealthService.luau",
    "PROGRESSION_SOURCE": SSS / "ProgressionService.luau",
}
C, U, HL, PR = "CONFIG_SOURCE", "UTIL_SOURCE", "HEALTH_SOURCE", "PROGRESSION_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # --- hours, bands, keys
    ("an hour is a day", HL, "return math.floor(num(t, os.time()) / 3600) * 3600", "return math.floor(num(t, os.time()) / 86400) * 86400"),
    ("the hour is missing from the key", HL, "return \"H\" .. os.date(\"!%Y%m%d%H\", h)", "return \"H\" .. os.date(\"!%Y%m%d\", h)"),
    ("the report time is not Korea time", HL, "return os.date(\"!%m-%d %H:%M\", t + 9 * 3600)", "return os.date(\"!%m-%d %H:%M\", t + 8 * 3600)"),
    ("the band edge belongs to the next band", HL, "if level <= num(b.Max, 1000) then return b.Name end", "if level < num(b.Max, 1000) then return b.Name end"),
    ("a level is never floored", HL, "level = math.floor(num(level, 1))\n\tlocal list = bands()", "level = num(level, 1)\n\tlocal list = bands()"),
    ("the last band is the first", HL, "return list[#list].Name\nend", "return list[1].Name\nend"),
    ("keys are not cleaned", HL, "\tk = string.gsub(tostring(k), \"[^%w_%-%+]\", \"\")\n", ""),
    ("keys are not cut", HL, "\treturn string.sub(k, 1, 24)\n", "\treturn k\n"),
    ("an empty key stays empty", HL, "\tif k == \"\" then return \"Other\" end\n", ""),
    ("the cap counts Other too", HL, "\t\tif k ~= \"Other\" then n += 1 end\n", "\t\tn += 1\n"),
    ("a player with no level is level 99", HL, "return num(player:GetAttribute(\"Level\"), 1)", "return num(player:GetAttribute(\"Level\"), 99)"),
    # --- recorders
    ("a join counts twice", HL, "\td.Joins = (d.Joins or 0) + 1\n", "\td.Joins = (d.Joins or 0) + 2\n"),
    ("a minute counts every player in band 1", HL, "local band = bandOf(levelOf(p))\n\t\tmins[band]", "local band = bandOf(1)\n\t\tmins[band]"),
    ("Peak is the last count, not the most", HL, "d.Peak = math.max(d.Peak or 0, #ready)", "d.Peak = #ready"),
    ("a zero gold is a key", HL, "\tif amount <= 0 or type(source) ~= \"string\" then return end\n\tlocal d = delta()\n\tbump(sub(d, \"GoldIn\")",
     "\tif amount < 0 or type(source) ~= \"string\" then return end\n\tlocal d = delta()\n\tbump(sub(d, \"GoldIn\")"),
    ("gold in is not floored", HL, "\tamount = math.floor(num(amount))\n\tif amount <= 0 or type(source) ~= \"string\" then return end", "\tamount = num(amount)\n\tif amount <= 0 or type(source) ~= \"string\" then return end"),
    ("gold in has no band", HL, "\tbump(sub(d, \"GoldIn\"), source, amount)\n\tlocal band = sub(sub(d, \"GoldBand\"), bandOf(levelOf(player)))\n\tband.In = (band.In or 0) + amount\n",
     "\tbump(sub(d, \"GoldIn\"), source, amount)\n"),
    ("gold out is counted as in", HL, "\tbump(sub(d, \"GoldOut\"), sink, amount)", "\tbump(sub(d, \"GoldIn\"), sink, amount)"),
    ("gold out has no band", HL, "\tband.Out = (band.Out or 0) + amount\n", ""),
    ("a non-string sink is counted", HL, "\tif amount <= 0 or type(sink) ~= \"string\" then return end", "\tif amount <= 0 then return end"),
    ("XP goes to band 1", HL, "\tlocal band = bandOf(levelOf(player))\n\txp[band]", "\tlocal band = bandOf(1)\n\txp[band]"),
    ("XP is not floored", HL, "function HealthService.OnXP(player, amount)\n\tamount = math.floor(num(amount))", "function HealthService.OnXP(player, amount)\n\tamount = num(amount)"),
    ("a zero XP is a key", HL, "\tif amount <= 0 then return end\n\tlocal xp = sub(delta(), \"XP\")", "\tlocal xp = sub(delta(), \"XP\")"),
    ("goose: the winners are swapped", HL, "local key = result == \"Halo\" and \"HaloWins\" or result == \"Horns\" and \"HornsWins\" or \"Ties\"",
     "local key = result == \"Halo\" and \"HornsWins\" or result == \"Horns\" and \"HaloWins\" or \"Ties\""),
    ("goose: a tie is a Halo win", HL, "or result == \"Horns\" and \"HornsWins\" or \"Ties\"", "or result == \"Horns\" and \"HornsWins\" or \"HaloWins\""),
    ("goose: nobody-eligible rounds are versus", HL, "\telseif mode == \"Pending\" then\n\t\tg.Empty = (g.Empty or 0) + 1\n", "\telseif false then\n\t\tg.Empty = (g.Empty or 0) + 1\n"),
    ("goose: every co-op round is won", HL, "\t\tif info.Success == true then g.CoopWins = (g.CoopWins or 0) + 1 end\n", "\t\tg.CoopWins = (g.CoopWins or 0) + 1\n"),
    ("goose: co-op rounds are not counted", HL, "\t\tg.Coop = (g.Coop or 0) + 1\n", ""),
    ("goose: rounds are not counted", HL, "\tg.Rounds = (g.Rounds or 0) + 1\n", ""),
    ("goose: lost and won swapped", HL, "local key = info.Won == true and \"Won\" or \"Lost\"", "local key = info.Won == true and \"Lost\" or \"Won\""),
    ("goose: every pay is rare", HL, "\tif info.Rare == true then g.Rare = (g.Rare or 0) + 1 end\n", "\tg.Rare = (g.Rare or 0) + 1\n"),
    ("goose: gold is not floored", HL, "local gold, xp = math.max(0, math.floor(num(info.Gold))), math.max(0, math.floor(num(info.XP)))",
     "local gold, xp = math.max(0, num(info.Gold)), math.max(0, math.floor(num(info.XP)))"),
    ("goose: the band is the first one", HL, "local b = sub(sub(d, \"GooseBand\"), bandOf(info.Level))", "local b = sub(sub(d, \"GooseBand\"), bandOf(1))"),
    ("goose: a bad payload is a pay", HL, "function HealthService.OnGooseRewarded(_player, info)\n\tif type(info) ~= \"table\" then return end\n",
     "function HealthService.OnGooseRewarded(_player, info)\n\tinfo = type(info) == \"table\" and info or {}\n"),
    ("plunder: returned sacks are lost", HL, "local PLUNDER = { Paid = \"Paid\", Avenged = \"Avenged\", Returned = \"Returned\" }", "local PLUNDER = { Paid = \"Paid\", Avenged = \"Avenged\" }"),
    ("plunder: an unknown outcome counts as paid", HL, "local name = type(outcome) == \"string\" and PLUNDER[outcome] or nil", "local name = type(outcome) == \"string\" and PLUNDER[outcome] or \"Paid\""),
    ("plunder: gold is not floored", HL, "math.max(0, math.floor(num(total)))", "math.max(0, num(total))"),
    ("pass: a view is a prompt", HL, "local kind = id == \"PassView\" and \"View\" or", "local kind = id == \"PassView\" and \"Prompt\" or"),
    ("pass: no prompts", HL, "or id == \"PurchasePrompt\" and \"Prompt\" or nil", "or false and \"Prompt\" or nil"),
    ("pass: a metric counts every call", HL, "\tif seen[key] and now - seen[key] < METRIC_GAP then return end\n", ""),
    ("pass: the slot is shared by everyone", HL, "\tlocal seen = METRIC_SEEN[player]\n\tif not seen then\n\t\tseen = {}\n\t\tMETRIC_SEEN[player] = seen\n\tend\n",
     "\tlocal seen = METRIC_SEEN.All or {}\n\tMETRIC_SEEN.All = seen\n"),
    ("pass: the slot ignores the pass", HL, "local key = kind .. \":\" .. passRow(arg)", "local key = kind"),
    ("pass: the slot ignores the step", HL, "local key = kind .. \":\" .. passRow(arg)", "local key = passRow(arg)"),
    ("pass: the gap is a day", HL, "local METRIC_GAP = 3600", "local METRIC_GAP = 86400"),
    ("pass: the hour is never over", HL, "now - seen[key] < METRIC_GAP", "now - seen[key] <= METRIC_GAP"),
    ("pass: a caller with no player counts", HL, " or typeof(player) ~= \"Instance\" then return end", " then return end"),
    ("pass: a look id is its own row", HL, "if type(Config.Looks) == \"table\" and type(Config.Looks[id]) == \"table\" then return \"Look\" end\n", ""),
    ("pass: a number is a pass id", HL, "\tif type(id) ~= \"string\" or (kind ~= \"View\"", "\tif (kind ~= \"View\""),
    ("pass: any kind", HL, "(kind ~= \"View\" and kind ~= \"Prompt\" and kind ~= \"Bought\") then return end", "false then return end"),
    # --- the document
    ("merge: Peak is added", HL, "local MAXED = { Peak = true }", "local MAXED = {}"),
    ("merge: huge numbers pass", HL, "if v == v and v > -1e12 and v < 1e12 then", "if v == v then"),
    ("merge: non-string keys pass", HL, "\t\tif type(k) == \"string\" then\n\t\t\tlocal key = cleanKey(k)", "\t\tif true then\n\t\t\tlocal key = cleanKey(k)"),
    ("merge: any depth", HL, "elseif type(v) == \"table\" and depth < 3 then", "elseif type(v) == \"table\" and depth < 9 then"),
    ("merge: no key cap", HL, "\t\t\tif depth > 1 and dst[key] == nil and count(dst) >= maxKeys() then key = \"Other\" end\n", ""),
    ("merge: no version", HL, "\tout.V = 1\n\treturn out", "\treturn out"),
    ("merge: text values are sums", HL, "\t\t\tif type(v) == \"number\" then\n\t\t\t\tif v == v", "\t\t\tif type(v) == \"number\" or type(v) == \"string\" then\n\t\t\t\tif v == v"),
    ("flush: Studio writes the real store", HL, "\t\tif RunService:IsStudio() then name ..= \"_STUDIO\" end\n\t\tlocal ok, st = pcall(DataStoreService.GetDataStore, DataStoreService, name)\n\t\tSTORE",
     "\t\tlocal ok, st = pcall(DataStoreService.GetDataStore, DataStoreService, name)\n\t\tSTORE"),
    ("flush: no environment in the store name", HL, "local name = Config.StoreName and Config.StoreName(base) or base\n\t\tif RunService:IsStudio() then name ..= \"_STUDIO\" end\n\t\tlocal ok, st = pcall(DataStoreService.GetDataStore, DataStoreService, name)\n\t\tSTORE",
     "local name = base\n\t\tif RunService:IsStudio() then name ..= \"_STUDIO\" end\n\t\tlocal ok, st = pcall(DataStoreService.GetDataStore, DataStoreService, name)\n\t\tSTORE"),
    ("flush: servers are never counted", HL, "\t\tif not b.Counted then mine.Servers = 1 end\n", ""),
    ("flush: a server is counted at every flush", HL, "\t\tif ok then\n\t\t\tb.Counted = true\n", "\t\tif ok then\n"),
    ("flush: sums stay after a write", HL, "\t\tlocal mine = b.Delta\n\t\tb.Delta = {} -- what is added while the write waits goes to the next flush\n", "\t\tlocal mine = b.Delta\n"),
    ("flush: a failed write loses the sums", HL, "\t\t\tb.Delta = back\n", "\t\t\tb.Delta = {}\n"),
    ("flush: the news since a failure are lost", HL, "\t\t\tsumInto(back, b.Delta, 1)\n", ""),
    ("flush: a failure is reported as success", HL, "\t\t\tallOk = false\n", ""),
    ("flush: no warning on a failure", HL, "\t\t\tUtil.Warn(TAG, \"save \" .. hourKey(h) .. \": \" .. tostring(err))\n", ""),
    ("flush: the document is overwritten", HL, "\t\t\treturn HealthService.Merge(old, mine)\n", "\t\t\treturn HealthService.Merge(nil, mine)\n"),
    ("flush: empty hours are written", HL, "\t\tif next(b.Delta) ~= nil then table.insert(hours, h) end\n", "\t\ttable.insert(hours, h)\n"),
    ("read: live reads the Studio copy", HL, "if which ~= \"live\" and RunService:IsStudio() then name ..= \"_STUDIO\" end", "if RunService:IsStudio() then name ..= \"_STUDIO\" end"),
    ("read: no hour cap", HL, "math.max(1, math.floor(num(H.MaxReadHours, 72)))", "math.huge"),
    ("read: zero hours read nothing", HL, "hours = math.clamp(math.floor(num(hours, num(H.ReadHours, 24))), 1,", "hours = math.clamp(math.floor(num(hours, num(H.ReadHours, 24))), 0,"),
    ("read: newest first", HL, "for i = hours - 1, 0, -1 do", "for i = 0, hours - 1 do"),
    ("read: the default is 6 hours", HL, "num(hours, num(H.ReadHours, 24))", "num(hours, 6)"),
    ("read: a failed read throws the rows away", HL, "if not ok then return rows, tostring(doc) end", "if not ok then return {}, tostring(doc) end"),
    ("read: a document is not repaired", HL, "table.insert(rows, { T = h, Doc = HealthService.Merge(doc, nil) })", "table.insert(rows, { T = h, Doc = doc })"),
    # --- the report
    ("alerts: quiet needs 4 hours", HL, "if newest and now - (newest.T + 3600) >= num(A.QuietHours, 3) * 3600 then", "if newest and now - (newest.T + 3600) > num(A.QuietHours, 3) * 3600 then"),
    ("alerts: an hour still running is judged", HL, "\t\tif r.T + 3600 <= now then table.insert(full, r) end", "\t\ttable.insert(full, r)"),
    ("alerts: the end of the hour is not full yet", HL, "\t\tif r.T + 3600 <= now then table.insert(full, r) end", "\t\tif r.T + 3600 < now then table.insert(full, r) end"),
    ("alerts: 60 player-minutes are not enough", HL, "\t\t\t\tif mins >= minMin then\n\t\t\t\t\tlastIdx = i", "\t\t\t\tif mins > minMin then\n\t\t\t\t\tlastIdx = i"),
    ("alerts: thin hours are a baseline", HL, "\t\t\t\t\tif bm >= minMin then\n\t\t\t\t\t\tbaseV += bv", "\t\t\t\t\tif bm >= minMin - 5 then\n\t\t\t\t\t\tbaseV += bv"),
    ("alerts: the newest hour may be thin", HL, "\t\t\t\tif mins >= minMin then\n\t\t\t\t\tlastIdx = i", "\t\t\t\tif true then\n\t\t\t\t\tlastIdx = i"),
    ("alerts: no baseline needed", HL, "if baseHours >= need and base1 and base1 > 0 and now1", "if base1 and base1 > 0 and now1"),
    ("alerts: one more baseline hour needed", HL, "if baseHours >= need and", "if baseHours > need and"),
    ("alerts: exactly 2x does not flag", HL, "and now1 >= ratio * base1 then", "and now1 > ratio * base1 then"),
    ("alerts: 1.5x flags", HL, "and now1 >= ratio * base1 then", "and now1 >= 0.75 * ratio * base1 then"),
    ("alerts: rate per minute, not per hour", HL, "return value / (minutes / 60)", "return value / minutes"),
    ("alerts: the goose needs 11 rounds", HL, "if halo + horns >= num(A.GooseMinRounds, 10) then", "if halo + horns > num(A.GooseMinRounds, 10) then"),
    ("alerts: 75% is not lopsided", HL, "if top / (halo + horns) >= num(A.GooseSkew, 0.75) then", "if top / (halo + horns) > num(A.GooseSkew, 0.75) then"),
    ("alerts: ties count against the winner", HL, "if top / (halo + horns) >= num(A.GooseSkew, 0.75) then", "if top / (halo + horns + num(g.Ties)) >= num(A.GooseSkew, 0.75) then"),
    ("alerts: the lopsided side is always Halo", HL, "halo > horns and \"Halo\" or \"Horns\"", "\"Halo\""),
    ("alerts: gold surges use the XP", HL, "\t\t\t\t\tlocal gb = type(doc.GoldBand) == \"table\" and doc.GoldBand[name]\n\t\t\t\t\tv = type(gb) == \"table\" and num(gb.In) or 0",
     "\t\t\t\t\tv = type(doc.XP) == \"table\" and num(doc.XP[name]) or 0"),
    ("text: the biggest source is last", HL, "if a[2] ~= b[2] then return a[2] > b[2] end", "if a[2] ~= b[2] then return a[2] < b[2] end"),
    ("text: the net is always plus", HL, "goldIn - goldOut >= 0 and \"+\" or \"-\"", "\"+\""),
    ("text: the net is in versus out", HL, "fmt(math.abs(goldIn - goldOut))", "fmt(goldIn + goldOut)"),
    ("text: player-hours are minutes", HL, "string.format(\"%s %.1f\", b.Name, num(mins[b.Name]) / 60)", "string.format(\"%s %.1f\", b.Name, num(mins[b.Name]))"),
    ("text: goose pay is the sum, not the average", HL, "num(g.Paid) > 0 and fmt(num(g.Gold) / num(g.Paid)) or \"-\",\n\t\t\tnum(g.Paid)", "num(g.Paid) > 0 and fmt(num(g.Gold)) or \"-\",\n\t\t\tnum(g.Paid)"),
    ("text: plunder average over the wrong count", HL, "num(n) > 0 and fmt(num(gold) / num(n)) or \"-\")", "num(n) > 0 and fmt(num(gold)) or \"-\")"),
    ("text: no alert lines", HL, "\tlocal alerts = HealthService.Alerts(rows, now)\n", "\tlocal alerts = {}\n"),
    ("text: the pending label is stored", HL, "\treturn HealthService.Text(HealthService.Pending(), os.time(), \"this server, not saved yet\")", "\treturn HealthService.Text(HealthService.Pending(), os.time(), \"stored\")"),
    ("text: a bad value reads the live store", HL, "\tif which == \"stored\" or which == \"live\" then\n\t\tlocal rows, err = HealthService.ReadRows(which, hours)", "\tif true then\n\t\tlocal rows, err = HealthService.ReadRows(which or \"live\", hours)"),
    ("text: the read failure is not shown", HL, "\t\tif err then text ..= \"\\n(read stopped: \" .. err .. \")\" end\n", ""),
    # --- start
    ("start: no join count", HL, "\tconnect(\"PlayerService\", \"PlayerReady\", HealthService.OnJoin)\n", ""),
    ("start: no gold in", HL, "\tconnect(\"ProgressionService\", \"GoldEarned\", HealthService.OnGoldIn)\n", ""),
    ("start: no gold out", HL, "\tconnect(\"ProgressionService\", \"GoldSpent\", HealthService.OnGoldOut)\n", ""),
    ("start: no XP", HL, "\tconnect(\"ProgressionService\", \"XPEarned\", HealthService.OnXP)\n", ""),
    ("start: no goose rounds", HL, "\tconnect(\"GooseService\", \"GooseFinished\", HealthService.OnGooseFinished)\n", ""),
    ("start: no goose pay", HL, "\tconnect(\"GooseService\", \"GooseRewarded\", HealthService.OnGooseRewarded)\n", ""),
    ("start: no plunder", HL, "\tconnect(\"GrudgeService\", \"SackResolved\", HealthService.OnSack)\n", ""),
    ("start: no pass views", HL, "\tconnect(\"TelemetryService\", \"ClientMetric\", HealthService.OnClientMetric)\n", ""),
    ("start: no bought passes", HL, "\tconnect(\"MonetizationService\", \"PassBought\", function(_player, kind) HealthService.OnPass(\"Bought\", kind) end)\n", ""),
    ("start: no minute loop", HL, "\t\t\tlocal ok, err = pcall(HealthService.Minute)\n", "\t\t\tlocal ok, err = true, nil\n"),
    ("start: the minute loop waits 10", HL, "\t\t\ttask.wait(60)\n\t\t\tlocal ok, err = pcall(HealthService.Minute)", "\t\t\ttask.wait(600)\n\t\t\tlocal ok, err = pcall(HealthService.Minute)"),
    ("start: every server writes at once", HL, "\t\t\ttask.wait(every * (0.5 + Util.Random:NextNumber())) -- servers do not all write in the same second", "\t\t\ttask.wait(every)"),
    ("start: the wait is 10x", HL, "task.wait(every * (0.5 + Util.Random:NextNumber()))", "task.wait(every * (5 + Util.Random:NextNumber()))"),
    ("start: no flush loop", HL, "\t\t\tpcall(HealthService.Flush)\n\t\tend\n\tend)\n\tgame:BindToClose", "\t\tend\n\tend)\n\tgame:BindToClose"),
    ("start: no flush at the close", HL, "\tgame:BindToClose(function()\n\t\tpcall(HealthService.Flush)\n\tend)\n", ""),
    ("start: the switch is ignored", HL, "\tif H.Enabled == false then return end\n", ""),
    # --- Config
    ("Config: another store", C, "\tStore = \"HaloHorns_Health_v1\",", "\tStore = \"HaloHorns_Health_v2\","),
    ("Config: flush every 60 s", C, "\tFlushSeconds = 600,\n\tReadHours = 24,", "\tFlushSeconds = 60,\n\tReadHours = 24,"),
    ("Config: read 6 hours", C, "\tReadHours = 24,\n\tMaxReadHours = 72,", "\tReadHours = 6,\n\tMaxReadHours = 72,"),
    ("Config: 10 keys", C, "\tMaxKeys = 40,\n\tBands", "\tMaxKeys = 10,\n\tBands"),
    ("Config: the first band ends at 10", C, "{ Name = \"1-9\", Max = 9 }", "{ Name = \"1-9\", Max = 10 }"),
    ("Config: no top band cap", C, "{ Name = \"50+\", Max = 1000 }", "{ Name = \"50+\", Max = 60 }"),
    ("Config: the surge ratio is 3", C, "SurgeRatio = 2,", "SurgeRatio = 3,"),
    ("Config: 2 baseline hours", C, "MinBaseline = 3,", "MinBaseline = 2,"),
    ("Config: 30 player-minutes", C, "MinPlayerMinutes = 60,", "MinPlayerMinutes = 30,"),
    ("Config: goose skew 90%", C, "GooseSkew = 0.75,", "GooseSkew = 0.9,"),
    ("Config: quiet after 6 hours", C, "QuietHours = 3 },", "QuietHours = 6 },"),
    # --- the real ProgressionService
    ("XP is never fired", PR, "\tM.XPEarned:Fire(player, amount, source)\n", ""),
    ("XP is fired double", PR, "\tM.XPEarned:Fire(player, amount, source)\n", "\tM.XPEarned:Fire(player, amount * 2, source)\n"),
]


READ_ONLY_KEYS = {"Errors", "Health", "StoryDump", "DataDump", "LootRoll"}


def debug_taint_problems(main: str) -> list[str]:
    """The DebugCommand taint rule: only the read-only keys leave the save clean (the other keys all mark DebugTainted)."""
    out: list[str] = []
    m = re.search(r"local READ_ONLY = \{(.*?)\}", main)
    keys = set(re.findall(r"(\w+) = true", m.group(1))) if m else set()
    if keys != READ_ONLY_KEYS:
        out.append(f"READ_ONLY keys are {sorted(keys)}")
    guard = "if tainted and not READ_ONLY[key] then tainted.DebugTainted = true end"
    if guard not in main:
        out.append("the taint line is not guarded by READ_ONLY")
    elif main.find(guard) > main.find('key == "RankSettle"'):
        out.append("the taint line is after the key branches")
    return out


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
    check(init_list.count("HealthService") == 1 and start_list.count("HealthService") == 1, "HealthService is in both lists once")
    check(start_list.index("HealthService") < start_list.index("PlayerService") and start_list[-1] == "PlayerService",
          "HealthService starts before PlayerService (it listens to PlayerReady)")
    check(sorted(init_list) == sorted(start_list), "every service is in both lists")
    check('key == "Health"' in main and "S.HealthService.Debug(" in main, "DebugCommand('Health') calls HealthService.Debug")
    check(debug_taint_problems(main) == [], "DebugCommand: only Errors / Health / StoryDump / DataDump / LootRoll leave the save untainted: " + "; ".join(debug_taint_problems(main)))
    guard = "if tainted and not READ_ONLY[key] then tainted.DebugTainted = true end"
    for name, mutated in (("a read-only key taints", main.replace("tainted and not READ_ONLY[key]", "tainted", 1)),
                          ("Gold is read-only", main.replace("LootRoll = true }", "LootRoll = true, Gold = true }", 1)),
                          ("Health taints", main.replace("Health = true, ", "", 1)),
                          ("the taint line moves below the branches", main.replace(guard, "", 1) + "\n" + guard)):
        check(mutated != main and debug_taint_problems(mutated) != [], f"static mutation caught: {name}")
    health = read(SSS / "HealthService.luau")
    code = strip_comments(health)
    check("Config.StoreName" in code, "HealthService's store name goes through Config.StoreName (Beta / Live get their own)")
    check(len(re.findall(r"GetDataStore", code)) == 2, "two DataStore handles only (write path and read path), both named through Config.StoreName")
    check(not re.search(r"[가-힣]", code), "HealthService: no Korean outside comments")
    check("MarketplaceService" not in code and "AddBankGold" not in code and "AddStat" not in code and "GrantItem" not in code,
          "HealthService: nothing sold, nothing paid")
    check("UserId" not in code and "player.Name" not in code and "DisplayName" not in code, "HealthService: no UserId, no player name")
    check(code.count("UpdateAsync") == 1 and "SetAsync" not in code, "documents are only merged (one UpdateAsync, no SetAsync)")
    prog = strip_comments(read(SSS / "ProgressionService.luau"))
    check("M.XPEarned = Util.Signal.new()" in prog, "ProgressionService.XPEarned exists")
    fire = prog.find("M.XPEarned:Fire(player, amount, source)")  # Codex B6: + the source
    add = prog.find("function M.AddXP")
    ret = prog.find("return amount", fire if fire > 0 else 0)
    check(add >= 0 and fire > add and 0 < ret - fire < 80, "AddXP fires XPEarned(player, amount, source) right before it returns")
    check(prog.count("M.XPEarned:Fire") == 1, "XPEarned has one fire site (AddXP)")
    goose = strip_comments(read(SSS / "GooseService.luau"))
    check("GooseService.GooseRewarded = Util.Signal.new()" in goose, "GooseService.GooseRewarded exists")
    reward = goose.find("local function rewardPlayer")
    fire = goose.find("GooseService.GooseRewarded:Fire(p, {")
    finish = goose.find("local function finish")
    check(0 <= reward < fire < finish and goose.count("GooseRewarded:Fire") == 1,
          "rewardPlayer fires GooseRewarded once, after the pay and the notices")
    check("Won = won" in goose[fire:fire + 200] and "Gold = gold" in goose[fire:fire + 200] and "XP = xp" in goose[fire:fire + 200]
          and "Level = level" in goose[fire:fire + 200], "GooseRewarded carries Won / Gold / XP / Level")
    for signal, src in (("GooseFinished", "GooseService"), ("SackResolved", "GrudgeService"), ("PassBought", "MonetizationService"),
                        ("GoldEarned", "ProgressionService"), ("GoldSpent", "ProgressionService")):
        check(re.search(rf"\b{signal} = Util\.Signal\.new\(\)", read(SSS / f"{src}.luau")) is not None, f"{src}.{signal} exists (HealthService listens)")
    for service, signal in (("ProgressionService", "GoldEarned"), ("ProgressionService", "GoldSpent"), ("ProgressionService", "XPEarned"),
                            ("GooseService", "GooseFinished"), ("GooseService", "GooseRewarded"), ("GrudgeService", "SackResolved"),
                            ("TelemetryService", "ClientMetric"), ("MonetizationService", "PassBought"), ("PlayerService", "PlayerReady")):
        check(f'connect("{service}", "{signal}"' in code, f"HealthService listens to {service}.{signal}")
    cfg = strip_comments(read(SHARED / "Config.luau"))
    check(cfg.count("Config.Health = {") == 1, "Config.Health exists once")
    return count, failures


SUITE = Suite(
    mark="HEALTH",
    fixture=ROOT / "tools/fixtures/health_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-09/offline_dev3_health_2026-10-09.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="HealthService: read-only observer. Per UTC hour it sums joins, player-minutes per level band, the most ready players "
             "on one server, gold in / out per source / sink and per band, XP per band (ProgressionService.XPEarned), the goose "
             "(rounds, Halo / Horns wins, ties, co-op, nobody paid; pay per player: GooseService.GooseRewarded) , plunder sacks "
             "(count / gold per outcome), pass view -> prompt -> bought. Sums tables hold at most 40 keys (+ Other), keys are "
             "cleaned, no name or id. Every FlushSeconds (x0.5..1.5) and at the close the unsaved sums are merged (UpdateAsync) "
             "into ONE document per UTC hour 'H<YYYYMMDDHH>' in Config.StoreName('HaloHorns_Health_v1') (Studio: _STUDIO); "
             "numbers added, Peak the larger, Servers counted once per server and hour; a failed write keeps the sums for "
             "the next flush; events during a write go to the next. DebugCommand('Health'[, 'stored' | 'live'[:hours]]) "
             "prints totals, rates per player-hour and ALERT lines (QUIET, SURGE of XP / gold per player-hour vs the earlier "
             "hours, GOOSE lopsided).",
    limitations="Real DataStore limits and throttling are not simulated (one UpdateAsync per hour per server per flush is far "
                "under them); the Studio command (DebugCommand) is wired by source (static). The alert numbers are starter "
                "values (Config.Health.Alerts) to tune after the first real tests.",
)

if __name__ == "__main__":
    run(SUITE)
