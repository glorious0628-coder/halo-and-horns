"""A23-61 server aim (검수 2026-10-07): a basic swing at a monster behind me lands, offline.

Game dev 1 measured in Studio that the server sees the client's FaceTarget turn 0.27-0.43 s after it, so a monster
behind me was missed 3 / 3. CombatService.Swing aims at the nearest monster within Range in any direction when nothing is
inside the front half (AimCone) and turns the root to it; players and the golden goose keep the front-half rule; auto
combat swings at a monster behind too. Runs the CURRENT Config, Util, CombatService, LootService, StoryQuestService,
PvPService and the ShopService / JusticeService extracts of tools/test_unarmed_start.py on
tools/fixtures/dev2_combat_world.luau with tools/fixtures/swing_aim_offline.luau and the installed official Luau CLI. No
Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_swing_aim.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-07/offline_dev2_swing_aim_2026-10-07.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SSS, Suite, function_block, read, run
from test_unarmed_start import FILES, bindings

CO = "COMBAT_SOURCE"

MUTATIONS = [
    ("no turn to a monster behind", CO, "\tif not frontTarget(player, root, pos, w, range, isManual, goosePos, gooseReach) then\n",
     "\tif false then\n"),
    ("always the nearest monster (the front ignored)", CO,
     "\tif not frontTarget(player, root, pos, w, range, isManual, goosePos, gooseReach) then\n", "\tif true then\n"),
    ("the turn reaches past Range", CO, "local near = monstersNear(player, pos, range)[1]", "local near = monstersNear(player, pos, range + 20)[1]"),
    ("the body is not turned", CO, "\tpcall(function() root.CFrame = CFrame.lookAt(pos, pos + look) end)\n", ""),
    ("a turned Around sweep hits players", CO, "\t\tif isManual and not turned then\n\t\t\tvictims = aimed(playersNear(player, pos, range), aimRoot, w.AimCone)",
     "\t\tif isManual then\n\t\t\tvictims = aimed(playersNear(player, pos, range), aimRoot, w.AimCone)"),
    ("a turned swing counts the goose", CO, "hitGoose = goosePos ~= nil and not turned and Util.FlatDistance(goosePos, pos) <= range + gooseReach",
     "hitGoose = goosePos ~= nil and Util.FlatDistance(goosePos, pos) <= range + gooseReach"),
    ("the front check ignores players", CO, "\tif isManual and #aimed(playersNear(player, pos, range), root, w.AimCone) > 0 then return true end\n", ""),
    ("Splash keeps the old facing", CO, "local nearMon = aimed(monstersNear(player, pos, range), aimRoot, w.AimCone)",
     "local nearMon = aimed(monstersNear(player, pos, range), root, w.AimCone)"),
    ("Multi keeps the old facing", CO, "for _, m in aimed(monstersNear(player, pos, range), aimRoot, w.AimCone) do",
     "for _, m in aimed(monstersNear(player, pos, range), root, w.AimCone) do"),
    ("Around keeps the old facing", CO, "monsters = aimed(monstersNear(player, pos, range), aimRoot, w.AimCone)",
     "monsters = aimed(monstersNear(player, pos, range), root, w.AimCone)"),
    ("auto swings only at the front half", CO, "and #monstersNear(p, pos, w.Range or 10) > 0 then",
     "and #aimed(monstersNear(p, pos, w.Range or 10), root, w.AimCone) > 0 then"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    combat = read(SSS / "CombatService.luau")
    check("local function inAim(root, pos, cone)\n" in combat, "inAim keeps its shape (tools/test_aim_cone.py cuts it out)")
    swing = function_block(combat, "function CombatService.Swing(")
    check(swing.count("turnTo(root, pos, near.Pos)") == 1, "Swing turns once, to the nearest monster")
    release = function_block(combat, "function CombatService.Release(")
    check("aimRoot" not in release, "skills are not part of this change (SKL-2 brings the same rule to Q / Z)")
    return count, failures


SUITE = Suite(
    mark="SWING_AIM",
    fixture=ROOT / "tools/fixtures/swing_aim_offline.luau",
    world=ROOT / "tools/fixtures/dev2_combat_world.luau",
    out=ROOT / "docs/art/verification_2026-10-07/offline_dev2_swing_aim_2026-10-07.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-61 + 검수 2026-10-07: a swing with no monster / player / goose inside the front half (AimCone) aims at the "
             "nearest monster within Range in any direction (the client FaceTarget rule) and turns the root to it "
             "(CFrame.lookAt); the swing is then judged from that facing (Around: its front half, Splash / Multi: that "
             "target first) on monsters only - players and the goose keep the real front-half rule. Something inside the "
             "front half always wins (no turn). Auto combat swings whenever a monster is within Range (same rule).",
    limitations="The real network delay and the client's own turn are not simulated; the root turn is a CFrame.lookAt "
                "double. Skills Q / Z get the same rule in SKL-2 (SkillService).",
)

if __name__ == "__main__":
    run(SUITE)
