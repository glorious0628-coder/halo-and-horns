"""⑫ Pumpkin King vs Ghost King 9-day banter (docs/design/lines_pack_2026-10-06.md §4), offline.

Runs the CURRENT Config (Halloween.Banter), Util, AnnounceService and HalloweenService on tools/fixtures/dev2_kit.luau
with tools/fixtures/banter_offline.luau and the installed official Luau CLI. Kings come through
HalloweenService.DebugSpawn (the same appear / finish code as the schedule). No Studio, network, DataStore or Roblox
API calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_banter.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_dev2_banter_2026-10-06.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "ANNOUNCE_SOURCE": SSS / "AnnounceService.luau",
    "HALLOWEEN_SOURCE": SSS / "HalloweenService.luau",
}
C, H = "CONFIG_SOURCE", "HALLOWEEN_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    ("%d never filled (shows raw)", H, '\tif string.find(line, "%d", 1, true) then\n', "\tif false then\n"),
    ("the zero line ignored", H, "(K.Defeats <= 0 and type(zero) == \"string\") and zero or", "false and zero or"),
    ("beaten kings never counted", H, "\tif defeated then K.Defeats += 1 end", "\tlocal _ = defeated"),
    ("a king going home counts", H, "\tif defeated then K.Defeats += 1 end", "\tK.Defeats += 1"),
    ("no banter sent", H, "{ Banter = okLine and line or nil }", "{ Banter = nil }"),
    ("no clamp below Day 1", H, "math.clamp(math.floor((Config.SeasonNow() - num(B.DayOneStart)) / 86400) + 1, 1, #B.Days)",
     "math.min(math.floor((Config.SeasonNow() - num(B.DayOneStart)) / 86400) + 1, #B.Days)"),
    ("one day late", H, "num(B.DayOneStart)) / 86400) + 1, 1,", "num(B.DayOneStart)) / 86400) + 0, 1,"),
    ("UTC days instead of KST", C, "DayOneStart = 1793372400,", "DayOneStart = 1793404800,"),
    ("no speaker name", H, 'return string.format(type(B.Format) == "string" and B.Format or "%s: \\"%s\\"", (m and (m.Short or m.Name)) or b.Kind, line)',
     "return line"),
    ("the Ghost King says the Pumpkin King's line", H, "B.Days[day][b.Key] or nil", "B.Days[day].PumpkinKing or nil"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    hs = read(SSS / "HalloweenService.luau")
    appear = function_block(hs, "local function appear(")
    check('announce(b.Key .. "Appear", { Banter =' in appear, "the banter rides on the Appear broadcast (Args.Banter)")
    check("Net.Notify" not in hs and "NotifyAll" not in hs, "no toast: chat only (the Announce event line)")
    return count, failures


SUITE = Suite(
    mark="BANTER",
    fixture=ROOT / "tools/fixtures/banter_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-06/offline_dev2_banter_2026-10-06.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="⑫ (lines_pack §4): HalloweenService sends today's line (Config.Halloween.Banter, KST day = floor((SeasonNow "
             "- DayOneStart) / 86400) + 1 clamped 1..9) as Args.Banter of the <Key>Appear broadcast, formatted "
             "'Short: \"line\"'. The Day 9 Ghost King line is filled FIRST with this server's beaten kings (memory "
             "only; a king that goes home does not count; none -> GhostKingZero), then formatted. Game dev 1's Announce "
             "shows Args.Banter as the next chat line in the event's Color (no toast).",
    limitations="The chat line itself is game dev 1's (Announce.luau: Args.Banter -> a second system message, same "
                "color, no toast). The schedule loop is not run; DebugSpawn uses the same appear / finish code.",
)

if __name__ == "__main__":
    run(SUITE)
