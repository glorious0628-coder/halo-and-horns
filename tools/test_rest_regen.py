"""A23-224 rest regen, final (user 2026-10-17: "너무 빨리 차 … 빛 1초에 2%(그대로), 뿔 1초에 1%"), offline.

Inside Config.Combat.RestRegen.Zones (SlimeMeadow), at any level, a side listed in Wait (the Horns and the guild: 5 s) that took no
damage for that long gets PerSec (1%) of max HP a second from CombatService's regen loop (Stack false: the bigger of it and the
side's own, never added; Halo keeps its own 2%). Any damage stops it and the wait starts again. A town keeps its TownRegenPerSec, an
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
    ("Horns waits 1 s", C, "Wait = { Horns = 5, Neutral = 5 }", "Wait = { Horns = 1, Neutral = 5 }"),
    ("the guild left out", C, "Wait = { Horns = 5, Neutral = 5 }", "Wait = { Horns = 5 }"),
    ("2% a second", C, "Neutral = 5 }, PerSec = 0.01,", "Neutral = 5 }, PerSec = 0.02,"),
    ("Halo added and stacked (the dropped 4% plan)", C, "Wait = { Horns = 5, Neutral = 5 }, PerSec = 0.01, Stack = false }",
     "Wait = { Halo = 1, Horns = 5, Neutral = 5 }, PerSec = 0.01, Stack = true }"),
    ("a Default wait for every side", C, "Wait = { Horns = 5, Neutral = 5 }", "Wait = { Horns = 5, Neutral = 5, Default = 5 }"),
    ("every zone", CO, "R.Zones[zone] == true and wait", "wait"),
    ("no wait after a hit", CO, "and os.clock() - (lastDamagedAt[p] or -math.huge) >= wait then", "then"),
    ("an Active kaiju rests too", CO, "if type(R) == \"table\" and kstate(p) ~= \"Active\" and type(R.Zones) == \"table\" then",
     "if type(R) == \"table\" and type(R.Zones) == \"table\" then"),
]


def static() -> tuple[int, list[str]]:
    # r8 play (최종 검수 10/17: +2.3 HP/s at once = Roblox's default 1 %/s + ours): no engine "Health" regen script may run.
    # StarterCharacterScripts holds the empty replacement; PlayerService removes any "Health" script a character gets
    from dev2_offline import SSS, function_block, strip_comments
    failures, count = [], 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    rep = (ROOT / "src/StarterPlayer/StarterCharacterScripts/Health.server.luau").read_text(encoding="utf-8-sig")
    check(strip_comments(rep).strip() == "", "StarterCharacterScripts/Health is an empty Script (it replaces the engine's regen)")
    added = strip_comments(function_block((SSS / "PlayerService.luau").read_text(encoding="utf-8-sig"), "local function onCharacterAdded("))
    check('if child.Name == "Health" and child:IsA("Script") then pcall(child.Destroy, child) end' in added
          and "for _, child in character:GetChildren() do dropRegen(child) end" in added
          and "character.ChildAdded:Connect(dropRegen)" in added,
          "PlayerService.onCharacterAdded removes a 'Health' script now and when one comes later")
    return count, failures


SUITE = Suite(
    mark="REST_REGEN",
    fixture=ROOT / "tools/fixtures/rest_regen_offline.luau",
    world=ROOT / "tools/fixtures/dev2_combat_world.luau",
    out=ROOT / "docs/art/verification_2026-10-17/offline_dev2_rest_regen_2026-10-17.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-224 final: in the SlimeMeadow (any level) a Horns player's HP comes back at 1% of max a second once they took "
             "no damage for 5 s; any damage stops it and restarts the wait. Halo keeps its own 2% (nothing added), the other sides "
             "their own. Towns keep the town regen; an Active kaiju gets none; outside the meadow nothing changes. No text, no banner.",
    limitations="The regen loop is stepped by hand (RegenTick 1 s); the HP bar the client draws is game dev 1's.",
)

if __name__ == "__main__":
    run(SUITE)
