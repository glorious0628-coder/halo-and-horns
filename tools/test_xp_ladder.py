"""The XP ladder (Config.XPToNext, Config.Levels.Ramp; 최종 검수 10/14: the Lv10 cliff), offline.

Below EarlyUntil (10) a level needs EarlyMult (0.35) of the curve XPBase x level ^ XPExponent; Ramp gives the levels just
after it a share (10: 0.5, 11: 0.65, 12: 0.8, 13: 0.9) so the bar no longer jumps x3.3 at Lv10; every other level is the full
curve. Runs the CURRENT Config and Util on tools/fixtures/dev2_kit.luau with tools/fixtures/xp_ladder_offline.luau and the
installed official Luau CLI. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies only.

Usage: py tools/test_xp_ladder.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-14/offline_xp_ladder_2026-10-14.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, Suite, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
}
C = "CONFIG_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    ("the Ramp ignored", C, "\telseif type(L.Ramp) == \"table\" and type(L.Ramp[level]) == \"number\" then\n\t\tshare = L.Ramp[level]\n",
     "\telseif false then\n\t\tshare = L.Ramp[level]\n"),
    ("the Ramp before EarlyUntil", C, "\tif level < L.EarlyUntil then\n\t\tshare = L.EarlyMult -- addendum A7-2\n\telseif",
     "\tif false then\n\t\tshare = L.EarlyMult -- addendum A7-2\n\telseif"),
    ("Lv10 at the full curve", C, "Ramp = { [10] = 0.5, [11] = 0.65,", "Ramp = { [11] = 0.65,"),
    ("Lv13 left out", C, "[12] = 0.8, [13] = 0.9 },", "[12] = 0.8 },"),
    ("no floor of 1", C, "\tif share then xp = math.max(1, math.floor(xp * share)) end\n", "\tif share then xp = math.floor(xp * share) end\n"),
]


def static() -> tuple[int, list[str]]:
    config = read(SHARED / "Config.luau")
    ok = "function Config.XPToNext(level)" in config and config.count("Ramp = {") == 1
    return 1, ([] if ok else ["Config.XPToNext and one Config.Levels.Ramp table"])


SUITE = Suite(
    mark="XPLADDER",
    fixture=ROOT / "tools/fixtures/xp_ladder_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-14/offline_xp_ladder_2026-10-14.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="Config.XPToNext(level) = floor(XPBase x level ^ XPExponent) x EarlyMult (0.35) below EarlyUntil (10), x "
             "Config.Levels.Ramp[level] (10: 0.5, 11: 0.65, 12: 0.8, 13: 0.9) just after it, else the full curve; a share "
             "never makes it below 1. Lv1 -> Lv10 stays 962 XP.",
    limitations="The time a level takes depends on the monsters and the 2x passes (measured in the 10/17 test).",
)

if __name__ == "__main__":
    run(SUITE)
