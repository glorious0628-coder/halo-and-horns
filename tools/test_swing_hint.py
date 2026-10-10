"""A23-91 server target hint (dev2 2026-10-10): a manual swing / skill Q goes to the monster the client picked, offline.

The client (HUD.PickTarget, game dev 1) sends its pick - the monster Model - as argument 1 of the Swing and Release
remotes. CombatService takes it for MANUAL attacks only when it is the Model of an entry of the attack's own filter
(monstersNear: alive, mine or nobody's, the zone level gate, a boss's HitPad) within Range + HINT.Slack (2) and not a
hidden ambusher; then the root turns to it unless it is within HINT.KeepDeg (10 deg) of the facing (a turned attack hits
monsters only), Splash centres on it, Multi shoots it first, Around hits it even at Range + Slack (nobody else gets the
slack), a queued manual swing keeps it, and the skill Q (Target-centred classes) centres on it through SkillService (its
queued press too) or CombatService's own fallback. Anything else - a player's character, a part, a dead / far / hidden /
someone else's / zone-gated monster, a wrong type, more arguments than the pick, any auto attack - is ignored: exactly
the swing of today (A23-61). Runs the CURRENT Config, Util, CombatService, LootService, StoryQuestService, PvPService,
DamageWindow and SkillService plus the ShopService / JusticeService extracts of tools/test_unarmed_start.py on
tools/fixtures/dev2_combat_world.luau with tools/fixtures/swing_hint_offline.luau and the installed official Luau CLI. No
Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_swing_hint.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-10/offline_dev2_swing_hint_2026-10-10.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SSS, Suite, function_block, read, run, strip_comments
from test_unarmed_start import FILES as UNARMED_FILES, bindings as unarmed_bindings

FILES = dict(UNARMED_FILES)
FILES["WINDOW_SOURCE"] = SSS / "DamageWindow.luau"
FILES["SKILL_SOURCE"] = SSS / "SkillService.luau"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = unarmed_bindings(sources)
    for key in ("WINDOW_SOURCE", "SKILL_SOURCE"):
        out[key] = sources[key]
    return out


CO, SK = "COMBAT_SOURCE", "SKILL_SOURCE"
SWING_REMOTE_HEAD = "local function onSwingRemote(player, hint, ...)\n\tif select(\"#\", ...) ~= 0 then hint = nil end\n"
RELEASE_REMOTE_HEAD = "local function onReleaseRemote(player, hint, ...)\n\tif select(\"#\", ...) ~= 0 then hint = nil end\n"

MUTATIONS = [
    # --- the validation (HINT.Pick)
    ("a wrong type reaches the Instance calls (no typeof)", CO,
     "if typeof(hint) ~= \"Instance\" or not hint:IsA(\"Model\")", "if not hint:IsA(\"Model\")"),
    ("a model marked Hidden is accepted", CO, " or hint:GetAttribute(\"Hidden\") == true then return nil end", " then return nil end"),
    ("a hidden ambusher (server flag) is accepted", CO,
     "\t\t\tif e.Rec._hidden == true then return nil end -- MonsterService MOB3.Hide: waiting in the flowers\n", ""),
    ("the pick skips the swing's filter (owner / zone gate)", CO,
     "\tfor _, e in monstersNear(player, pos, range + HINT.Slack) do\n",
     "\tfor _, r in S.MonsterService.GetMonstersInRadius(pos, range + HINT.Slack, player) do\n"
     "\t\tlocal e = { Rec = r, Pos = r.Root.Position, Dist = Util.FlatDistance(r.Root.Position, pos) }\n"),
    ("no slack for the pick", CO, "monstersNear(player, pos, range + HINT.Slack) do", "monstersNear(player, pos, range) do"),
    ("a slack of 4 (a pick at Range + 3 accepted)", CO, "local HINT = { Slack = 2,", "local HINT = { Slack = 4,"),
    # --- the facing (HINT.Aim)
    ("the root never turns to the pick", CO, "\tlocal r = turnTo(root, pos, e.Pos)\n\treturn r, r ~= root\n", "\treturn root, false\n"),
    ("always a turn (KeepDeg ignored)", CO, "\tif inAim(root, e.Pos, HINT.KeepDeg) then return root, false end\n", ""),
    ("KeepDeg 90 (a pick at 45 deg does not turn)", CO, "Slack = 2, KeepDeg = 10 }", "Slack = 2, KeepDeg = 90 }"),
    ("a turned pick swing still hits players", CO, "\t\taimRoot, turned = HINT.Aim(root, pos, hinted)\n",
     "\t\taimRoot = HINT.Aim(root, pos, hinted)\n"),
    # --- Swing
    ("Swing ignores the pick", CO, "local hinted = isManual and HINT.Pick(player, pos, range, hint) or nil",
     "local hinted = nil"),
    ("auto swings take a pick", CO, "local hinted = isManual and HINT.Pick(player, pos, range, hint) or nil",
     "local hinted = HINT.Pick(player, pos, range, hint) or nil"),
    ("Splash keeps the nearest as centre", CO,
     "\t\tif hinted then pickPos, pickIsGoose = hinted.Pos, false end -- A23-91: the orb goes to the client's pick\n", ""),
    ("Multi: the pick not first", CO,
     "\t\tif hinted then\n\t\t\ttable.insert(candidates, 1, { Kind = \"M\", Entry = hinted, Pos = hinted.Pos, Dist = hinted.Dist })\n\t\tend\n", ""),
    ("Multi: the pick shot twice", CO, "\t\t\tif not (hinted and m.Rec == hinted.Rec) then -- A23-91", "\t\t\tif true then -- A23-91"),
    ("Around: the pick at Range + Slack is not added", CO,
     "\t\tif hinted then monsters = HINT.First(hinted, monsters) end -- A23-91: the pick even at Range + Slack, nobody else\n", ""),
    ("Around: the slack for everyone", CO,
     "\t\tmonsters = aimed(monstersNear(player, pos, range), aimRoot, w.AimCone)\n\t\tif hinted then",
     "\t\tmonsters = aimed(monstersNear(player, pos, range + HINT.Slack), aimRoot, w.AimCone)\n\t\tif hinted then"),
    ("Around: the pick hit twice", CO, "\t\tif m.Rec ~= e.Rec then table.insert(out, m) end\n", "\t\ttable.insert(out, m)\n"),
    # --- the remotes and the queue
    ("the Swing remote drops the pick", CO, "\t\tCombatService.Swing(player, true, hint)\n", "\t\tCombatService.Swing(player, true)\n"),
    ("Swing: extra arguments keep the pick", CO, SWING_REMOTE_HEAD, SWING_REMOTE_HEAD.split("\n")[0] + "\n"),
    ("the queue is given no pick", CO, "\t\tqueueManualSwing(player, hint)\n", "\t\tqueueManualSwing(player)\n"),
    ("the queued swing drops its pick", CO, "CombatService.Swing(player, true, request.Hint)", "CombatService.Swing(player, true)"),
    ("the Release remote drops the pick (SkillService)", CO,
     "skills.Cast(player, \"Q\", false, hint) -- SKL-2", "skills.Cast(player, \"Q\", false) -- SKL-2"),
    ("the Release remote drops the pick (no SkillService)", CO,
     "CombatService.Release(player, false, hint) -- MarkActive inside", "CombatService.Release(player, false) -- MarkActive inside"),
    ("Release: extra arguments keep the pick", CO, RELEASE_REMOTE_HEAD, RELEASE_REMOTE_HEAD.split("\n")[0] + "\n"),
    # --- Release (Q)
    ("Q ignores the pick", CO, "local hinted = not isAuto and HINT.Pick(player, pos, range, hint) or nil", "local hinted = nil"),
    ("auto Q takes a pick", CO, "local hinted = not isAuto and HINT.Pick(player, pos, range, hint) or nil",
     "local hinted = HINT.Pick(player, pos, range, hint) or nil"),
    ("a turned Q on the pick hits players", CO, "\t\t\tbestPos, turnedQ = hinted.Pos, turned\n", "\t\t\tbestPos = hinted.Pos\n"),
    # --- SkillService
    ("SkillService drops the pick before Q", SK, "\tif slot == \"Q\" then return castQ(player, s, isAuto, hint) end\n",
     "\tif slot == \"Q\" then return castQ(player, s, isAuto) end\n"),
    ("castQ drops the pick", SK, "S.CombatService.Release(player, isAuto, hint) == true", "S.CombatService.Release(player, isAuto) == true"),
    ("a queued Q drops its pick", SK, "pcall(SkillService.Cast, player, slot, false, hint)", "pcall(SkillService.Cast, player, slot, false)"),
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
    code = strip_comments(combat)
    # tools/test_auto_face.py (game dev 1) keeps Config.AutoFace.ServerHint false while this line is in CombatService
    check("function CombatService.Swing(player, isManual)\n" not in combat
          and "function CombatService.Swing(player, isManual, hint)\n" in combat,
          "CombatService.Swing takes the pick (test_auto_face.py's gate allows ServerHint = true)")
    check("function CombatService.Release(player, isAuto, hint)\n" in combat, "CombatService.Release takes the pick")
    pick = function_block(combat, "function HINT.Pick(")
    check(pick.count("monstersNear(player, pos, range + HINT.Slack)") == 1 and "GetMonstersInRadius" not in pick,
          "the pick is checked only against the swing's own filter (monstersNear)")
    swing = function_block(combat, "function CombatService.Swing(")
    check(swing.count("HINT.Pick(") == 1 and swing.count("turnTo(root, pos, near.Pos)") == 1,
          "Swing: one pick check; the A23-61 turn stays for no pick")
    release = function_block(combat, "function CombatService.Release(")
    check(release.count("HINT.Pick(") == 1, "Release: one pick check (the Target centre)")
    auto = function_block(combat, "local function autoTick(")
    check("CombatService.Swing(p, false)\n" in auto and "skills.Cast(p, \"Q\", true)" in auto
          and "CombatService.Release(p, true)\n" in auto and "hint" not in auto, "the auto loop sends no pick")
    check(len(re.findall(r"OnServerEvent:Connect\(", code)) == 3, "no new remote (Swing / Release / SetAutoAttack)")
    block = combat[combat.find("local HINT = {"):combat.find("-- other alive Halo players")]
    check("Config.Text" not in block and "Net." not in block and "Notify" not in block, "the pick adds no player-facing text")
    skill = read(SSS / "SkillService.luau")
    use = function_block(skill, "local function onUseSkill(")
    check("SkillService.Cast(player, slot, false)\n" in use, "UseSkill (Z / X) carries no pick")
    return count, failures


SUITE = Suite(
    mark="SWING_HINT",
    fixture=ROOT / "tools/fixtures/swing_hint_offline.luau",
    world=ROOT / "tools/fixtures/dev2_combat_world.luau",
    out=ROOT / "docs/art/verification_2026-10-10/offline_dev2_swing_hint_2026-10-10.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-91 server target hint: Swing / Release arg 1 = the client's pick (a monster Model). Valid only for a "
             "MANUAL attack and only when it is the Model of a monstersNear entry (alive, mine or nobody's, zone level "
             "gate, boss HitPad) within Range + HINT.Slack (2) and not hidden (rec._hidden / Model attribute Hidden). "
             "Valid: the root turns to it unless within HINT.KeepDeg (10 deg) of the facing; a turned attack hits "
             "monsters only (no player, no goose). Splash: centre = the pick. Multi: the pick first, then the nearest, "
             "no repeat. Around: the front half of the pick direction plus the pick itself even at Range + Slack "
             "(nobody else gets the slack). The queued manual swing keeps its pick; Q (ReleaseCenter Target) centres on "
             "the pick through SkillService (queued press too) or CombatService's fallback; a Self-centred Q ignores it. "
             "Anything else (wrong type, part, player character, dead / far / hidden / someone else's / gated monster, "
             "extra remote arguments, auto swings / auto Q) is ignored: the A23-61 swing of today.",
    limitations="The real client pick (HUD.PickTarget) and the network delay are not simulated (tools/test_auto_face.py "
                "covers the client). Splash keeps its blast radius around the pick, so a pick at Range + 2 reaches up to "
                "Range + 2 + Splash (as a pick inside Range always did). The IsA(\"Model\") guard is redundant with the "
                "Model identity check and is not mutated. The CFrame turn is the combat world's double.",
)

if __name__ == "__main__":
    run(SUITE)
