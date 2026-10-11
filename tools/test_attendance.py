"""A23-77 attendance = days collected (게임성 개발 3, 2026-10-08), offline.

Runs the CURRENT Config, Util, AttendanceService and TitleService on tools/fixtures/dev2_kit.luau +
tools/fixtures/dev3_world.luau with tools/fixtures/attendance_offline.luau and the installed official Luau CLI:
PlayerService / ProgressionService / LootService / MonetizationService are doubles (A23-75's GrantLook and the 2x passes
included). Static checks: the remote, the service lists, the debug hook. No Studio, network, DataStore or Roblox API
calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_attendance.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-08/offline_dev3_attendance_2026-10-08.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "ATTEND_SOURCE": SSS / "AttendanceService.luau",
    "TITLE_SOURCE": SSS / "TitleService.luau",
}
C, A = "CONFIG_SOURCE", "ATTEND_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # --- one claim a KST day, nothing resets
    ("a claim every call (no day check)", A, "and data.ClassChosen == true and a.LastDay < day", "and data.ClassChosen == true"),
    ("the day is not recorded", A, "\ta.LastDay = day\n\ta.Days += 1\n", "\ta.Days += 1\n"),
    ("a missed day resets the board (a streak)", A, "\tlocal slot = a.Slot\n\tlocal def = A.Board[slot]\n",
     "\tif a.LastDay > 0 and day - a.LastDay > 1 then a.Slot = 1 end\n\tlocal slot = a.Slot\n\tlocal def = A.Board[slot]\n"),
    ("a missed day resets the days collected", A, "\ta.LastDay = day\n\ta.Days += 1\n",
     "\tif a.LastDay > 0 and day - a.LastDay > 1 then a.Days = 0 end\n\ta.LastDay = day\n\ta.Days += 1\n"),
    ("the board never wraps", A, "\ta.Slot = slot % SLOTS + 1\n", "\ta.Slot = math.min(slot + 1, SLOTS)\n"),
    ("the board does not move", A, "\ta.Slot = slot % SLOTS + 1\n", "\ta.Slot = slot\n"),
    ("paid before the commit", A,
     "\ta.LastDay = day\n\ta.Days += 1\n\ta.Slot = slot % SLOTS + 1\n\tlocal days = a.Days\n\tpublish(player, data)\n\tlocal ok, out = pcall(pay, player, data, def)\n",
     "\tlocal ok, out = pcall(pay, player, data, def)\n\tif not ok then return end\n\ta.LastDay = day\n\ta.Days += 1\n\ta.Slot = slot % SLOTS + 1\n\tlocal days = a.Days\n\tpublish(player, data)\n"),
    ("the day line uses UTC", A, "\treturn Config.DayIndex(os.time())\n", "\treturn math.floor(os.time() / 86400)\n"),
    ("no day check for online players", A, "\t\tif type(data) == \"table\" and p.Parent ~= nil then publish(p, data) end\n", ""),
    # --- who may claim
    ("no class pick needed", A, "and data.ClassChosen == true and a.LastDay < day", "and a.LastDay < day"),
    ("the class pick does not open the claim", A,
     "\t\tplayer:GetAttributeChangedSignal(\"ClassChosen\"):Connect(function()\n", "\t\tplayer:GetAttributeChangedSignal(\"Level\"):Connect(function()\n"),
    ("arguments accepted", A, "\tif select(\"#\", ...) ~= 0 then return end\n", ""),
    ("no rate limit", A, "\tif not Util.RateLimit(player, \"ClaimAttendance\", num(Config.RateLimits.ClaimAttendance, 1)) then return end\n", ""),
    ("not-ready players claim", A, "\tif not S.PlayerService.IsReady(player) then return end\n\tif not Util.RateLimit", "\tif not Util.RateLimit"),
    # --- repairs
    ("a far-future LastDay blocks forever", A, "\tif a.LastDay > today() + 1 then a.LastDay = 0 end\n", ""),
    ("a broken slot stays broken", A, "\tif slot < 1 or slot > SLOTS then slot = 1 end\n", ""),
    ("negative days kept", A, "\ta.Days = math.max(0, math.floor(num(a.Days)))\n", "\ta.Days = math.floor(num(a.Days))\n"),
    # --- rewards
    ("gold tagged as a quest", A, "AddBankGold(player, amount, \"Attendance\")", "AddBankGold(player, amount, \"Quest\")"),
    ("the line shows the asked gold, not the added", A, "\treturn math.floor(num(got, amount))\nend\n\nlocal function addXP",
     "\treturn amount\nend\n\nlocal function addXP"),
    ("XP minutes paid as gold minutes", A, "\t\tlocal _, x = Config.HuntValue(level, def.XPMin)\n", "\t\tlocal x = Config.HuntValue(level, def.XPMin)\n"),
    ("bottles over the cap are lost", A, "\t\tif given < n and price then gold += (n - given) * num(price) end\n", ""),
    ("no materials", A, "\t\tfor _, m in materialsFor(level, def.MaterialMin) do item(m.Id, m.N) end\n", ""),
    ("materials of slimes for everyone", A, "\tlocal zone = Config.QuestZoneForLevel(level)\n", "\tlocal zone = \"SlimeMeadow\"\n"),
    ("no box flag", A, "Items = out.Items, Box = def.Box == true })", "Items = out.Items, Box = false })"),
    ("no Fx", A, "\tlocal okFx, errFx = pcall(Net.Fx, player, \"Attendance\", {", "\tlocal okFx, errFx = pcall(function() end, player, \"Attendance\", {"),
    ("no signal", A, "\tAttendanceService.Claimed:Fire(player, slot, days)\n", ""),
    # --- milestones
    ("no catch-up at join", A, "\tmilestones(player, a.Days, false) -- catch up", "\tlocal _ = milestones -- catch up"),
    ("the catch-up talks", A, "\tmilestones(player, a.Days, false) -- catch up", "\tmilestones(player, a.Days, true) -- catch up"),
    ("a look only on the exact day", A, "\t\tif need > 0 and need <= days then\n", "\t\tif need > 0 and need == days then\n"),
    ("sold looks given too", A,
     "\t\tlocal need = type(look) == \"table\" and type(look.Unlock) == \"table\" and num(look.Unlock.Attendance) or 0\n",
     "\t\tlocal need = type(look) == \"table\" and type(look.Unlock) == \"table\" and num(look.Unlock.Attendance) or 1\n"),
    ("every faction's look is announced", A, "\t\tif loud and look.Faction == faction then\n", "\t\tif loud then\n"),
    ("no milestone sound", A, "\t\t\t\tnotify(player, \"\", \"reward\", \"RankUp\")", "\t\t\t\tlocal _ = 0"),
    ("milestone text back (A23-130)", A, "\t\t\t\tnotify(player, \"\", \"reward\", \"RankUp\")",
     "\t\t\t\tnotify(player, string.format(\"%d days collected!\", at), \"reward\", \"RankUp\")"),
    ("titles only on the exact day", A, "\t\tif at > 0 and at <= days then\n", "\t\tif at > 0 and at == days then\n"),
    # --- Config
    ("Config: the 70% scroll on day 3 becomes a 10%", C, "\t\t{ Item = \"Enh70\", N = 1 },\n", "\t\t{ Item = \"Enh10\", N = 1 },\n"),
    ("Config: 'Regular' at 10 days", C, "\t\t{ Days = 7, Title = \"Regular\" },\n", "\t\t{ Days = 10, Title = \"Regular\" },\n"),
    ("Config: titles not pickable", C,
     "for _, id in { \"Regular\", \"SuperRegular\", \"MegaRegular\" } do\n\tif not table.find(Config.TitleOrder, id) then table.insert(Config.TitleOrder, id) end\n",
     "for _, id in { \"Regular\", \"SuperRegular\", \"MegaRegular\" } do\n"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    net = read(SHARED / "Net.luau")
    check(net.count('"ClaimAttendance"') == 1, "Net.Names has ClaimAttendance once")
    main = read(SSS / "Main.server.luau")
    init = re.search(r"local INIT_ORDER = \{(.*?)\n\}", main, re.S)
    start = re.search(r"local START_ORDER = \{(.*?)\n\}", main, re.S)
    names = re.compile(r'"(\w+)"')
    init_list = names.findall(init.group(1)) if init else []
    start_list = names.findall(start.group(1)) if start else []
    check("AttendanceService" in init_list and init_list.count("AttendanceService") == 1, "INIT_ORDER lists AttendanceService once")
    check("AttendanceService" in start_list and start_list[-1] == "PlayerService"
          and start_list.index("AttendanceService") < start_list.index("PlayerService"),
          "START_ORDER starts AttendanceService before PlayerService (PlayerService stays last)")
    check(sorted(init_list) == sorted(start_list), "every service is in both lists")
    check((SSS / "AttendanceService.luau").is_file(), "the service file exists (a listed module without a file hangs the server)")
    check('elseif key == "AttendNext" then' in main and "S.AttendanceService.DebugNextDay(player)" in main,
          "Studio DebugCommand AttendNext")
    attend = read(SSS / "AttendanceService.luau")
    check("Net.Get(\"ClaimAttendance\").OnServerEvent:Connect" in attend, "the service listens to ClaimAttendance")
    check(not re.search(r"[가-힣]", "\n".join(l.split("--", 1)[0] for l in attend.splitlines())),
          "no Korean outside comments (game text is English only, A23-48)")
    config = read(SHARED / "Config.luau")
    block = config[config.find("-- A23-77 attendance (게임성 개발 3"):]
    code = "\n".join(l.split("--", 1)[0] for l in block.splitlines())
    check(not re.search(r"[가-힣]", code), "Config attendance block: English text only")
    return count, failures


SUITE = Suite(
    mark="ATTEND",
    fixture=ROOT / "tools/fixtures/attendance_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-08/offline_dev3_attendance_2026-10-08.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-77: one claim a KST day (Config.DayIndex) of the next slot of the 7-slot board (2 HP potions, 3 min "
             "gold, Enh70, 3 min gold, 3 HP potions + 4 min of the level zone's materials, 5 min XP, the weekly box = 10 "
             "min gold + XP + Enh30), a missed day is skipped (no streak, nothing resets), slot 7 -> slot 1; committed "
             "before paying (never twice); class chosen, ready, no arguments, 1 s; data.Attendance { Days, LastDay, Slot } "
             "repaired at join; gold source 'Attendance' through ProgressionService (A23-75 2x inside it, the line shows "
             "what was added); bottles over the bag cap paid at the potion price; days collected 7 'Regular', 14, 28 "
             "name frame, 50 / 100 titles, attendance looks (Config.Looks Unlock.Attendance) via GrantLook for both "
             "factions, caught up silently at join; attributes AttendDays / AttendSlot / AttendReady (turns on at 00:00 KST "
             "for online players); Fx Attendance; signal Claimed.",
    limitations="The attendance window and the name frame are client work (game dev 1 / image dev). A23-75's Config.Looks / "
                "MonetizationService.GrantLook and the 2x passes are doubles here (game dev 2's branch is not on main). "
                "The real DataStore save of the field is DataService's (unchanged).",
)

if __name__ == "__main__":
    run(SUITE)
