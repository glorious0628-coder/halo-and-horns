"""A23-79 beta metrics (게임성 개발 3, 2026-10-08), offline.

docs/design/retention_round_2026-10-08.md "베타에서 잴 것": the funnels LongRoad / DailyVisit / Social / KingDiary /
PassShop (AnalyticsService:LogFunnelStepEvent), the events DaysPlayed, ReturnGap, PauseCard, WelcomeBack, Attendance,
FriendJoin, GoToFriend, DiaryPage, CandyTrade, NotifyOptIn, InviteSent, WelcomeBackGo, PromptNearKO, KOLeave60,
LeaveContext, and gold on the economy dashboard (LogEconomyEvent). Runs the CURRENT Config, Util and TelemetryService on
tools/fixtures/dev2_kit.luau + tools/fixtures/dev3_world.luau with tools/fixtures/beta_metrics_offline.luau and the
installed official Luau CLI; an AnalyticsService double records every call. Static checks: the event-name budget
(Roblox: 100 names), the funnel budget (10), the ClientMetric remote, no UserId in a logged field. No Studio, network,
DataStore or Roblox API calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_beta_metrics.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-08/offline_dev3_beta_metrics_2026-10-08.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "TELEMETRY_SOURCE": SSS / "TelemetryService.luau",
}
C, T = "CONFIG_SOURCE", "TELEMETRY_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # --- window ids (the pet window and the King's Diary are reported like the others)
    ("the Pet window is not a UiMetric id", C, "\"Feedback\", \"Pet\",\n\t\t\"Diary\" },", "\"Feedback\", \"Diary\" },"),
    ("the Diary window is not a UiMetric id", C, "\"Feedback\", \"Pet\",\n\t\t\"Diary\" },", "\"Feedback\", \"Pet\" },"),
    # --- funnel sessions
    ("Once funnels logged again on every call", T, "\tif done[name] then return false end\n\tdone[name] = true\n", "\tdone[name] = true\n"),
    ("DailyVisit session = UTC day", T, "\treturn Config.DayIndex(os.time())\nend\n\n-- the DailyVisit session",
     "\treturn math.floor(os.time() / 86400)\nend\n\n-- the DailyVisit session"),
    ("DailyVisit never starts a new day", T, "\tif type(tel.Visit) ~= \"table\" or tel.Visit.D ~= day then tel.Visit = { D = day, S = {} } end\n",
     "\tif type(tel.Visit) ~= \"table\" then tel.Visit = { D = day, S = {} } end\n"),
    ("a new shop visit on every click", T, "if not open or (name == \"ShopOpen\" and now - v.At >= num(A.ShopVisitGap, 30)) then",
     "if not open or name == \"ShopOpen\" then"),
    ("a visit never ends", T, "\tlocal open = v ~= nil and now - v.At < num(A.ShopVisitMax, 600)\n", "\tlocal open = v ~= nil\n"),
    ("one PassShop visit forever", T, "if not open or (name == \"ShopOpen\" and now - v.At >= num(A.ShopVisitGap, 30)) then",
     "if not open then"),
    ("a pass card without a visit is lost", T, "\tif name ~= \"ShopOpen\" then funnel(player, \"PassShop\", name) end\n",
     "\tif name ~= \"ShopOpen\" and open then funnel(player, \"PassShop\", name) end\n"),
    ("Bought outside an open visit", T, "\t\tif open then funnel(player, \"PassShop\", \"Bought\") end\n",
     "\t\tif T.Shop[player] then funnel(player, \"PassShop\", \"Bought\") end\n"),
    ("the Shop window opens no visit", T, "\tif id == \"Shop\" then shopStep(player, \"ShopOpen\") end\n", ""),
    ("step numbers from 0", T, "pcall(svc.LogFunnelStepEvent, svc, player, funnel, sessionId, index, name)",
     "pcall(svc.LogFunnelStepEvent, svc, player, funnel, sessionId, index - 1, name)"),
    # --- DailyVisit / DaysPlayed
    ("DaysPlayed every join", T, "\tif math.floor(num(tel.LastDay)) ~= day then\n", "\tif true then\n"),
    ("no day turn while online", T, "\t\t\tif data and T.Day[p] ~= today() then dayStart(p, data) end\n", ""),
    ("Daily3 only counts claims", T, "\tif claims + complete >= slots then funnel(player, \"DailyVisit\", \"Daily3\") end\n",
     "\tif claims >= slots then funnel(player, \"DailyVisit\", \"Daily3\") end\n"),
    ("no Daily1", T, "\tif claims >= 1 then funnel(player, \"DailyVisit\", \"Daily1\") end\n", ""),
    ("yesterday's dailies counted for today", T, "\tif not data or math.floor(num(data.DailyDay)) ~= today() then return end\n",
     "\tif not data then return end\n"),
    ("attendance as a funnel step", T, "\t\tTelemetryService.Custom(player, \"Attendance\", num(days), tostring(slot)) -- an optional moment: no funnel step\n",
     "\t\tTelemetryService.Custom(player, \"Attendance\", num(days), tostring(slot))\n\t\tfunnel(player, \"DailyVisit\", \"Daily1\")\n"),
    ("no pause-card step", T, "\t\tif why == \"Daily\" then funnel(player, \"DailyVisit\", \"StopCardSeen\") end\n", ""),
    ("every card ends the day's funnel", T, "\t\tif why == \"Daily\" then funnel(player, \"DailyVisit\", \"StopCardSeen\") end\n",
     "\t\tfunnel(player, \"DailyVisit\", \"StopCardSeen\")\n"),
    ("DaysPlayed without the level band", T, "TelemetryService.Custom(player, \"DaysPlayed\", tel.Days, bandOf(data.Level), tostring(data.Faction))",
     "TelemetryService.Custom(player, \"DaysPlayed\", tel.Days, nil, tostring(data.Faction))"),
    # --- ReturnGap
    ("ReturnGap for a brand-new save", T, "\tif last > 0 then TelemetryService.Custom(player, \"ReturnGap\"",
     "\tif true then TelemetryService.Custom(player, \"ReturnGap\""),
    ("ReturnGap buckets off by a day", T, "or h < 24 and \"6-24h\"", "or h < 48 and \"6-24h\""),
    # --- LongRoad
    ("no long-road catch-up", T, "\troadCatchUp(player, data)\n", ""),
    ("level steps only on the exact level", T, "\t\t\tif v >= at then funnel(player, \"LongRoad\", \"Level\" .. at) end\n",
     "\t\t\tif v == at then funnel(player, \"LongRoad\", \"Level\" .. at) end\n"),
    ("RuinsDaily at any level", T, "and v >= 1 and num(player:GetAttribute(\"Level\"), 1) >= 25 then", "and v >= 1 then"),
    ("RuinsDaily every claim", T, "\t\tif tel and not tel.RuinsDaily and v >= 1", "\t\tif tel and v >= 1"),
    ("no ChapterEnd", T, "\t\tif ch then TelemetryService.Custom(player, \"ChapterEnd\", ch) end", "\t\tif false then TelemetryService.Custom(player, \"ChapterEnd\", ch) end"),
    ("ChapterEnd for every main quest", T, "\t\tif ch and ch > 0 then last[ch] = id end\n", "\t\tif ch and ch > 0 then CHAPTER_END[id] = ch end\n"),
    ("no Rebirth1", T, "\twatch(player, \"Rebirths\", function(v) if num(v) >= 1 then funnel(player, \"LongRoad\", \"Rebirth1\") end end)\n", ""),
    # --- Social / invites / diary
    ("InviteeJoined logged for the invitee", T, "\t\tif typeof(inviter) == \"Instance\" then funnel(inviter, \"Social\", \"InviteeJoined\") end\n",
     "\t\tfunnel(invitee, \"Social\", \"InviteeJoined\")\n"),
    ("FriendJoin says nothing about the inviter", T, "inviter and \"InviterHere\" or \"InviterAway\"", "\"Invite\""),
    ("no PlayedTogether", T, "\t\tfunnel(inviter, \"Social\", \"PlayedTogether10m\")\n", ""),
    ("no diary catch-up", T, "\tdiaryCatchUp(player, type(data.Diary) == \"table\" and data.Diary.Pages or 0)\n", ""),
    ("every diary page is a step", T, "\tif pages >= 3 then funnel(player, \"KingDiary\", \"Page3\") end\n",
     "\tif pages >= 2 then funnel(player, \"KingDiary\", \"Page3\") end\n"),
    # --- ClientMetric
    ("any client metric id", T, "\tif rule == nil or not argOk(rule, arg) then return end\n", "\tif rule ~= nil and not argOk(rule, arg) then return end\n"),
    ("three arguments", T, "\tif n < 1 or n > 2 then return end\n", "\tif n < 1 then return end\n"),
    ("any count", T, "and arg >= 1 and arg <= 50 end", "end"),
    ("any invite source", T, "\tif rule == \"Source\" then return type(arg) == \"string\" and table.find(A.InviteSources or {}, arg) ~= nil end\n",
     "\tif rule == \"Source\" then return type(arg) == \"string\" end\n"),
    ("any pass id", T, "return type(arg) == \"string\" and #arg <= 32 and (table.find(A.PassIds or {}, arg) ~= nil",
     "return type(arg) == \"string\" and (true"),
    ("no per-minute budget", T, "\tif b.N >= num(A.ClientMetricPerMinute, 10) then return false end\n", ""),
    ("the budget never refills", T, "\tif now - b.Start >= 60 then b.Start, b.N = now, 0 end\n", "\tif b.Start == -math.huge then b.Start, b.N = now, 0 end\n"),
    ("once-ids every call", T, "\tif s.Once[id] then return false end\n", ""),
    ("the budget hides the signal", T, "\tif s and clientBudget(s, id) then\n", "\tif not (s and clientBudget(s, id)) then return end\n\tdo\n"),
    ("Once marked before the budget", T, "\tif s.Once[id] then return false end\n\tlocal now = os.clock()\n",
     "\tif s.Once[id] then return false end\n\tif table.find(A.ClientMetricOnce or {}, id) then s.Once[id] = true end\n\tlocal now = os.clock()\n"),
    ("PromptNearKO for every buy window", T, "\t\tif ko and not ko.Prompted and os.clock() - ko.At <= near then\n",
     "\t\tif ko and os.clock() - ko.At <= near then\n"),
    ("None takes an argument", T, "\tif rule == \"None\" then return arg == nil end\n", "\tif rule == \"None\" then return true end\n"),
    ("no rate limit", T, "\tif not Util.RateLimit(player, \"ClientMetric:\" .. id, num(Config.RateLimits.ClientMetric, 0.5)) then return end\n", ""),
    ("not-ready players count", T, "\tif not S.PlayerService.IsReady(player) then return end\n\tif not Util.RateLimit(player, \"ClientMetric:\"",
     "\tif not Util.RateLimit(player, \"ClientMetric:\""),
    ("ClientMetric not passed on", T, "\tT.ClientMetric:Fire(player, id, arg) -- every accepted call", "\t-- every accepted call"),
    ("PromptNearKO at any time", T, "\t\tif ko and not ko.Prompted and os.clock() - ko.At <= near then\n", "\t\tif ko and not ko.Prompted then\n"),
    ("no PromptNearKO after a failed scroll", T, "\t\telseif fail and s.FailPrompted ~= fail and os.clock() - fail <= near then\n",
     "\t\telseif false then\n"),
    # --- phone performance (ClientMetric Perf)
    ("Perf: any extra key", T, "\t\tif not PERF_KEYS[k] then return false end -- an extra key (or an array slot) is no frame sample\n", ""),
    ("Perf: any device", T, "return type(arg.D) == \"string\" and table.find(A.PerfDevices or {}, arg.D) ~= nil\n",
     "return type(arg.D) == \"string\"\n"),
    ("Perf: fractions", T, "\treturn type(v) == \"number\" and v == math.floor(v) and v >= lo and v <= hi\n",
     "\treturn type(v) == \"number\" and v >= lo and v <= hi\n"),
    ("Perf: no fps ceiling", T, "and whole(arg.F, 0, num(P.MaxFps, 240))", "and whole(arg.F, 0, math.huge)"),
    ("Perf: the lowest second above the average", T, "and whole(arg.W, 0, arg.F)", "and whole(arg.W, 0, num(P.MaxFps, 240))"),
    ("Perf: unbounded memory", T, "and whole(arg.M, 0, num(P.MaxMem, 16384))", "and whole(arg.M, 0, math.huge)"),
    ("Perf: unbounded quality", T, "and whole(arg.Q, 0, num(P.MaxQuality, 10))", "and whole(arg.Q, 0, math.huge)"),
    ("Perf: the rule accepts anything", T, "\tif rule == \"Perf\" then return perfOk(arg) end\n", "\tif rule == \"Perf\" then return true end\n"),
    ("Perf: PerfFpsLow for every sample", T, "\tif arg.W < num(P.Low, 20) then Custom(", "\tif true then Custom("),
    ("Perf: Low counts the limit too", T, "\tif arg.W < num(P.Low, 20) then Custom(", "\tif arg.W <= num(P.Low, 20) then Custom("),
    ("Perf: no PerfFpsLow at all", T, "\tif arg.W < num(P.Low, 20) then Custom(", "\tif false then Custom("),
    ("Perf: the average is the low value", T, "Custom(player, \"PerfFpsLow\", arg.W,", "Custom(player, \"PerfFpsLow\", arg.F,"),
    ("Perf: an unknown zone goes into the field", T, "if type(zone) ~= \"string\" or not Config.Zones[zone] then zone = \"Other\" end\n\tlocal quality",
     "if type(zone) ~= \"string\" then zone = \"Other\" end\n\tlocal quality"),
    ("Perf: no device field", T, "Custom(player, \"PerfFps\", arg.F, arg.D, zone, quality)", "Custom(player, \"PerfFps\", arg.F, nil, zone, quality)"),
    ("Perf: no quality field", T, "Custom(player, \"PerfMem\", arg.M, arg.D, zone, quality)", "Custom(player, \"PerfMem\", arg.M, arg.D, zone)"),
    ("Perf: memory logged as frames", T, "Custom(player, \"PerfMem\", arg.M,", "Custom(player, \"PerfMem\", arg.F,"),
    ("Perf: no minute between samples", T, "\tif not Util.RateLimit(player, \"Perf\", num(P.MinGap, 60)) then return end\n", ""),
    ("Perf: shares the minute budget", T, "if not okPerf then Util.Warn(\"TelemetryService\", \"Perf: \" .. tostring(errPerf)) end\n\t\treturn\n",
     "if not okPerf then Util.Warn(\"TelemetryService\", \"Perf: \" .. tostring(errPerf)) end\n"),
    ("Perf: the client's own table goes on", T, "T.ClientMetric:Fire(player, \"Perf\", { D = arg.D, F = arg.F, W = arg.W, M = arg.M, Q = arg.Q })",
     "T.ClientMetric:Fire(player, \"Perf\", arg)"),
    ("Perf: no signal", T, "\tT.ClientMetric:Fire(player, \"Perf\", { D = arg.D", "\tlocal _ = ({ D = arg.D"),
    ("Config: no Perf rule", C, "\tPerf = \"Perf\", -- the phone", "\tPerfX = \"Perf\", -- the phone"),
    ("Config: no Console", C, "Config.Analytics.PerfDevices = { \"Phone\", \"Tablet\", \"Desktop\", \"Console\" }",
     "Config.Analytics.PerfDevices = { \"Phone\", \"Tablet\", \"Desktop\" }"),
    ("Config: Low 0", C, "Config.Analytics.Perf = { Every = 120, MinGap = 60, Low = 20,", "Config.Analytics.Perf = { Every = 120, MinGap = 60, Low = 0,"),
    ("Config: MinGap 1", C, "Config.Analytics.Perf = { Every = 120, MinGap = 60,", "Config.Analytics.Perf = { Every = 120, MinGap = 1,"),
    # --- leave
    ("KOLeave60 at any time", T, "\t\tif ko and os.clock() - ko.At <= num(A.KOLeave, 60) then Custom(player, \"KOLeave60\"",
     "\t\tif ko then Custom(player, \"KOLeave60\""),
    ("no leave context", T, "\t\t\tCustom(player, \"LeaveContext\", 1, leaveContext(player), bucketOf(minutes))\n", ""),
    ("a shutdown counts as leaves", T, "\tif not (okClose and closing == true) then\n", "\tif true then\n"),
    ("a pause card never names the leave", T, "\tif T.CardAt[player] and now - T.CardAt[player] <= recent then return \"StopCard\" end\n", ""),
    ("idle never", T, ">= num(A.IdleAfter, 120) then return \"Idle\" end", ">= math.huge then return \"Idle\" end"),
    ("the Shop is just a menu", T, "return win.Id == \"Shop\" and \"Shop\" or \"Menu\"", "return \"Menu\""),
    ("the Forge walk is not logged", T, "\tconnect(\"QuestService\", \"ForgeReached\", function(player, seconds)\n\t\tTelemetryService.Custom(player, \"ForgeWalk\", math.floor(num(seconds)))\n\tend)\n", ""),
    ("the Forge walk logs fractions", T, "TelemetryService.Custom(player, \"ForgeWalk\", math.floor(num(seconds)))", "TelemetryService.Custom(player, \"ForgeWalk\", num(seconds))"),
    # --- economy
    ("an event per coin", T, "\t\tif s and type(source) == \"string\" and num(amount) > 0 then\n\t\t\tlocal e = econOf(player).In\n\t\t\te[source] = (e[source] or 0) + math.floor(num(amount))\n\t\tend\n",
     "\t\tif s and type(source) == \"string\" and num(amount) > 0 then\n\t\t\tlocal e = econOf(player).In\n\t\t\te[source] = (e[source] or 0) + math.floor(num(amount))\n\t\t\tflushEconomy(player)\n\t\tend\n"),
    ("no flush at the leave", T, "\tflushEconomy(player)\n\tfor _, t in", "\tfor _, t in"),
    ("sums never reset", T, "\tT.Econ[player] = { In = {}, Out = {} }\n\tlocal balance = 0\n", "\tlocal balance = 0\n"),
    ("no 5-minute flush", T, "\t\t\tfor _, p in ready do flushEconomy(p) end\n", ""),
    ("every flow a Gameplay type", T, "\t\t\tlocal kind = f[3][tag] or \"Gameplay\"\n", "\t\t\tlocal kind = \"Gameplay\"\n"),
    # --- Config
    ("Config: Attendance gold as Gameplay", C, "Config.Analytics.EconomySources = { Attendance = \"TimedReward\",",
     "Config.Analytics.EconomySources = { Attended = \"TimedReward\","),
    ("Config: DailyVisit steps out of order", C, "Steps = { \"Join\", \"Daily1\", \"Daily3\", \"SetChest\", \"StopCardSeen\" }",
     "Steps = { \"Join\", \"Daily3\", \"Daily1\", \"SetChest\", \"StopCardSeen\" }"),
    ("Config: once-ids forgotten", C, "Config.Analytics.ClientMetricOnce = { \"OptIn\", \"WelcomeBackGo\" }", "Config.Analytics.ClientMetricOnce = {}"),
]

CAUSES = 5  # FirstDeath_<By>: Player / Kaiju / Monster / Fall / Other (BB14)
PLUNDER = 3  # Plunder_Kept / _Avenged / _Returned


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    tel = read(SSS / "TelemetryService.luau")
    code = strip_comments(tel)
    names = set(re.findall(r'Custom\(\w+, "(\w+)"', code))
    config = read(SHARED / "Config.luau")
    ui = re.search(r"\tUiIds = \{(.*?)\}", config, re.S)
    ui_ids = re.findall(r'"(\w+)"', ui.group(1)) if ui else []
    total = len(names) + len(ui_ids) + CAUSES + PLUNDER
    check(total <= 100, f"custom event names {total} <= 100 (Roblox limit)")
    check({"DaysPlayed", "ReturnGap", "PauseCard", "WelcomeBack", "Attendance", "FriendJoin", "GoToFriend", "DiaryPage",
           "CandyTrade", "NotifyOptIn", "InviteSent", "WelcomeBackGo", "PromptNearKO", "KOLeave60", "LeaveContext",
           "ChapterEnd", "RuinsDaily", "PerfFps", "PerfFpsLow", "PerfMem"} <= names,
          "every A23-79 event name (and the three Perf ones) is logged somewhere")
    print(f"custom event names: {len(names)} + {len(ui_ids)} UI + {CAUSES} + {PLUNDER} = {total}")
    check(code.count("LogFunnelStepEvent") == 1 and code.count("LogEconomyEvent") == 1, "one funnel and one economy call site")
    net = read(SHARED / "Net.luau")
    check(net.count('"ClientMetric"') == 1, "Net.Names has ClientMetric once")
    plain = code.replace("tostring(player.UserId)", "").replace("local x, y = a.UserId, b.UserId", "")
    check("UserId" not in plain.replace("other.UserId", ""), "no UserId is ever logged (only throttle keys and the friend cache)")
    check(not re.search(r"[가-힣]", code), "no Korean outside comments")
    return count, failures


SUITE = Suite(
    mark="BETA_METRICS",
    fixture=ROOT / "tools/fixtures/beta_metrics_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-08/offline_dev3_beta_metrics_2026-10-08.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-79 beta metrics (only always-in-order steps in a funnel: Roblox completes the earlier steps of a later "
             "one): funnels LongRoad (Level15/25/30/40/50, Rebirth1; once per account, old saves catch up), DailyVisit (Join, "
             "Daily1, Daily3, SetChest, StopCardSeen = the daily card; session = the KST day now, the dailies only while "
             "DailyDay is today, a day that turns online starts a new one), Social (InviteSeen, InvitePrompt, "
             "InviteSent, InviteeJoined for the inviter, PlayedTogether10m), KingDiary (Page1/3/6/9, caught up), PassShop "
             "(ShopOpen = every Shop open = a new GUID session, PassView, PurchasePrompt, Bought from "
             "MonetizationService.PassBought); events DaysPlayed (lifetime days, level band, faction), ReturnGap (<6h / "
             "6-24h / 1-3d / 3d+), Attendance, PauseCard, WelcomeBack, FriendJoin, GoToFriend, DiaryPage, CandyTrade, "
             "NotifyOptIn, InviteSent, WelcomeBackGo, PromptNearKO (30 s after a KO / failed scroll), KOLeave60 and "
             "LeaveContext (KO / StopCard / DailyDone / Combat / Shop / Menu / Idle / Play + session bucket) at the leave; "
             "c->s ClientMetric(id, arg) with fixed rules (ready, 0.5 s per id); gold sums per source / sink -> "
             "LogEconomyEvent every 5 minutes and at the leave (Gold, SKU = tag, TimedReward / Shop / Gameplay). No UserId, "
             "name or free text in any field.",
    limitations="The real Roblox dashboards are not reached offline (Studio logs nothing). The client sends ClientMetric / "
                "UiMetric (game dev 1); MonetizationService.PassBought is game dev 2's signal to add. Signals of the new "
                "services are doubles here (their own suites test them).",
)

if __name__ == "__main__":
    run(SUITE)
