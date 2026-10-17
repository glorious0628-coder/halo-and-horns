"""A23-224 rest regen (user 2026-10-17: "(a)로 해" / "레벨 없이!" / "5초는 뿔 1초는 빛"), offline.

Inside Config.Combat.RestRegen.Zones (SlimeMeadow), at any level, once the player took no damage for Wait[faction] s (Horns 5,
Halo 1, else Default 5), CombatService's regen loop adds PerSec (2%) of max HP a second - on top of the side's own regen when
Stack (Halo: 4%/s), else the bigger one. Any damage stops it and the wait starts again. A town keeps its TownRegenPerSec, an
Active kaiju gets none. Runs the CURRENT Config and CombatService (the dev2_combat_world doubles; the regen loop stepped by
w:RegenTick) with tools/fixtures/rest_regen_offline.luau and the installed official Luau CLI. No Studio, network or Roblox API
calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_rest_regen.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-17/offline_dev2_rest_regen_2026-10-17.json
"""
from __future__ import annotations

from dev2_offline import ROOT, Suite, run
from test_unarmed_start import FILES, bindings

C, CO = "CONFIG_SOURCE", "COMBAT_SOURCE"

MUTATIONS = [
    ("Horns waits 1 s", C, "Wait = { Halo = 1, Horns = 5, Default = 5 }", "Wait = { Halo = 1, Horns = 1, Default = 5 }"),
    ("Halo waits 5 s", C, "Wait = { Halo = 1, Horns = 5, Default = 5 }", "Wait = { Halo = 5, Horns = 5, Default = 5 }"),
    ("3% a second", C, "PerSec = 0.02, Stack = true }", "PerSec = 0.03, Stack = true }"),
    ("Stack off", C, "PerSec = 0.02, Stack = true }", "PerSec = 0.02, Stack = false }"),
    ("every zone", CO, "R.Zones[zone] == true and wait", "wait"),
    ("no wait after a hit", CO, "and os.clock() - (lastDamagedAt[p] or -math.huge) >= wait then", "then"),
    ("an Active kaiju rests too", CO, "if type(R) == \"table\" and kstate(p) ~= \"Active\" and type(R.Zones) == \"table\" then",
     "if type(R) == \"table\" and type(R.Zones) == \"table\" then"),
    ("Stack ignored (always the bigger)", CO, "pct = R.Stack == true and own + rest or math.max(own, rest)", "pct = math.max(own, rest)"),
    ("Stack always", CO, "pct = R.Stack == true and own + rest or math.max(own, rest)", "pct = own + rest"),
    ("no Default wait", CO, "(tonumber(R.Wait[f]) or tonumber(R.Wait.Default))", "tonumber(R.Wait[f])"),
]


def static() -> tuple[int, list[str]]:
    return 0, []


SUITE = Suite(
    mark="REST_REGEN",
    fixture=ROOT / "tools/fixtures/rest_regen_offline.luau",
    world=ROOT / "tools/fixtures/dev2_combat_world.luau",
    out=ROOT / "docs/art/verification_2026-10-17/offline_dev2_rest_regen_2026-10-17.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-224: in the SlimeMeadow (any level) HP comes back at 2% of max a second once Horns took no damage for 5 s, Halo "
             "for 1 s (any other side 5 s); any damage stops it and restarts the wait. Stack = on top of the side's own regen "
             "(Halo 2% + 2%), else the bigger one. Towns keep the town regen; an Active kaiju gets none; outside the meadow nothing "
             "changes. No text, no banner.",
    limitations="The regen loop is stepped by hand (RegenTick 1 s); the HP bar the client draws is game dev 1's.",
)

if __name__ == "__main__":
    run(SUITE)
