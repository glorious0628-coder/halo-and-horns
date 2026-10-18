"""A23-113 ① big landings, server half (게임성 개발 2, 2026-10-11), offline.

The King Slime's every attack is a leap onto the ground where its target stands, with a circle a second ahead (model
attributes DropAt / DropTime / DropRadius / DropPos / DropFrom / DropHeight for game dev 1's LandShadow and Fx); Captain
Clatter's every 3rd attack is a slam around himself. The rule never changes: at the landing every valid target inside
DropRadius - Grace (flat, YRange up / down) is hit once, nobody else. The first-KO King's circle grows after each miss
(it keeps hopping until it lands); the retry King is beaten by stepping out (FirstKOService strike x mult).

Runs MonsterService's real LEAP section with its real targetable() on engine doubles and the current Config on
tools/fixtures/dev2_kit.luau + tools/fixtures/boss_leap_offline.luau with the installed official Luau CLI. The aiStep /
personalStep / SpawnPersonal / FirstKOService hooks are checked as source text (FirstKOService runs in
tools/test_first_ko_king.py). No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies only.

Usage: py tools/test_boss_leap.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-11/offline_dev2_boss_leap_2026-10-11.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, between, function_block, read, run

STARTER = ROOT / "src/StarterPlayer/StarterPlayerScripts"

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "MONSTER_SOURCE": SSS / "MonsterService.luau",
}
C, M = "CONFIG_SOURCE", "MONSTER_SOURCE"
SECTION = "------------------------------------------------------------------ A23-113 ① big landings"
NEXT = "------------------------------------------------------------------ A23-74 spacing"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    mon = sources[M]
    out_y = re.search(r"^local OUT_Y = .*$", mon, re.M)
    if not out_y:
        raise ValueError("MonsterService OUT_Y missing; update the test extractor.")
    return {
        "CONFIG_SOURCE": sources[C],
        "UTIL_SOURCE": sources["UTIL_SOURCE"],
        "LEAP_EXTRACT": (
            "local Config, Util, H = ...\n"
            "local MC = Config.Monsters\n"
            "local records, FACE, S, Players = H.records, H.FACE, H.S, H.Players\n"
            "local isPlayerInTown, warnThrottled, groundPoint = H.isPlayerInTown, H.warnThrottled, H.groundPoint\n"
            "local ATTACK_SEQ_ATTR = \"AttackSeq\"\n"
            + out_y.group(0) + "\n"
            + function_block(mon, "local function targetable(")
            + between(mon, SECTION, NEXT)
            + "\nLEAP._targetable = targetable -- the test asks the AI's pick rule too (A23-227)\nreturn LEAP\n"),
    }


MUTATIONS = [
    ("r9: a personal King lands on the feet", M, "\t\tif rec.Owner ~= nil then\n\t\t\tlocal back = Vector3.new(from.X - aim.X, 0, from.Z - aim.Z)", "\t\tif false then\n\t\t\tlocal back = Vector3.new(from.X - aim.X, 0, from.Z - aim.Z)"),
    ("r8: the leap cycle ignored", M, "math.max(LEAP.Cycle(L), LEAP.Num(rec._leapCycle, 0))", "LEAP.Cycle(L)"),
    # A23-227 the field King's shield
    ("A23-227: no shield", M, "\t\t\tif not done then return false end\n", ""),
    ("A23-227: shield at any level", M, "\t\t\tand lv < (tonumber(F.FieldSafeBelow) or 0) then\n", "\t\t\tthen\n"),
    ("A23-227: shield until another quest", M, "st.Done[F.FieldSafeUntil] == true", "st.Done.M1_1 == true"),
    # who is hit
    ("no dodge (anyone near)", M, "if Util.FlatDistance(pos, J.Spot) > math.max(0, J.Radius - math.max(0, LEAP.Num(B.Grace, 0.5))) then return false end",
     "if Util.FlatDistance(pos, J.Spot) > 40 then return false end"),
    ("no grace", M, "J.Radius - math.max(0, LEAP.Num(B.Grace, 0.5))", "J.Radius"),
    ("no height rule", M, "\tif math.abs(pos.Y - J.Spot.Y) > math.max(0, LEAP.Num(B.YRange, 12)) then return false end\n", ""),
    ("the dead are hit", M, "if typeof(p) ~= \"Instance\" or p.Parent == nil or not Util.IsAlive(p) then return false end",
     "if typeof(p) ~= \"Instance\" or p.Parent == nil then return false end"),
    ("towns not safe (personal)", M, "return p == rec.Owner and pos.Y >= OUT_Y and not town", "return p == rec.Owner and pos.Y >= OUT_Y"),
    ("anyone hit by a personal King", M, "return p == rec.Owner and pos.Y >= OUT_Y and not town", "return pos.Y >= OUT_Y and not town"),
    ("no targetable rules", M, "\treturn targetable(rec, { Player = p, Pos = pos, Town = town, Zone = Config.ZoneAt(pos).Id })\n",
     "\treturn true\n"),
    ("only the target is hit", M, "\tfor _, p in Players:GetPlayers() do\n\t\tif LEAP.Victim(rec, J, p) then",
     "\tfor _, p in { J.Target } do\n\t\tif LEAP.Victim(rec, J, p) then"),
    ("strike hook skipped", M, "\t\t\tif rec._strike then\n\t\t\t\tok, err = pcall(rec._strike, rec, p, J.Mult)",
     "\t\t\tif false then\n\t\t\t\tok, err = pcall(rec._strike, rec, p, J.Mult)"),
    ("strike without mult", M, "pcall(rec._strike, rec, p, J.Mult)", "pcall(rec._strike, rec, p)"),
    ("plain hit without mult", M, "(tonumber(rec.Def.Damage) or 1) * J.Mult", "(tonumber(rec.Def.Damage) or 1)"),
    # landing life
    ("lands after it died", M, "\tif not rec.Alive or records[rec.Id] ~= rec then return 0 end\n\tlocal model = rec.Model\n\tif not model",
     "\tlocal model = rec.Model\n\tif not model"),
    ("an old landing still lands", M, "\tif type(J) ~= \"table\" or J.Token ~= token then return 0 end\n\trec._leap = nil",
     "\tif type(J) ~= \"table\" then return 0 end\n\trec._leap = nil"),
    ("never free again", M, "\trec._leap = nil\n\tif rec._windup == token then rec._windup = nil end\n\tif not rec.Alive",
     "\tif not rec.Alive"),
    ("an instant landing", M, "\ttask.delay(warn, function()\n\t\tlocal ok, err = pcall(LEAP.Land, rec, token)",
     "\ttask.delay(0, function()\n\t\tlocal ok, err = pcall(LEAP.Land, rec, token)"),
    ("swings during a landing", M, "\trec._windup, rec._leap = token, J\n", "\trec._leap = J\n"),
    ("slam without AttackSeq", M, "\t\tmodel:SetAttribute(ATTACK_SEQ_ATTR, (type(seq) == \"number\" and seq or 0) + 1) -- the swing",
     "\t\tlocal _ = seq -- the swing"),
    # growth
    ("no growth", M, "\tif n == 0 and LEAP.Num(rec._leapGrow, 0) > 0 then\n", "\tif false then\n"),
    ("grows on a hit too", M, "\tif n == 0 and LEAP.Num(rec._leapGrow, 0) > 0 then\n", "\tif LEAP.Num(rec._leapGrow, 0) > 0 then\n"),
    ("growth uncapped", M, "rec._leapExtra = math.min(math.max(0, LEAP.Num(rec._leapGrowMax, 0)), LEAP.Num(rec._leapExtra, 0) + rec._leapGrow)",
     "rec._leapExtra = LEAP.Num(rec._leapExtra, 0) + rec._leapGrow"),
    ("growth not in the radius", M, "return math.clamp(r + math.max(0, LEAP.Num(rec._leapExtra, 0)),", "return math.clamp(r,"),
    ("radius not clamped", M, "return math.clamp(r + math.max(0, LEAP.Num(rec._leapExtra, 0)), LEAP.Num(LS.MinRadius, 3), LEAP.Num(LS.MaxRadius, 40))",
     "return r + math.max(0, LEAP.Num(rec._leapExtra, 0))"),
    ("radius ignores the kind", M, "local r = LEAP.Num(radii[rec.Kind], nil) or LEAP.Num(radii.Default, 10)", "local r = LEAP.Num(radii.Default, 10)"),
    # start
    ("spot = its own feet (no leap)", M, "\t\tspot = g\n\tend\n\tlocal warn", "\tend\n\tlocal warn"),
    ("leaps out of its zone", M, "if not g or (rec.Owner == nil and Config.ZoneAt(g).Id ~= rec.ZoneId) then",
     "if not g then"),
    ("no retry delay", M, "\t\t\trec._nextAttackAt = now + math.max(0.1, LEAP.Num(B.RetryDelay, 0.5))\n", ""),
    ("bare place ignored", M, "\t\tif noHit then g = Vector3.new(aim.X, from.Y, aim.Z) end -- bare test place: flat ground\n", ""),
    ("no DropAt", M, "\tmodel:SetAttribute(\"DropAt\", Util.Now())", "\tlocal _ = Util.Now()"),
    ("no DropPos", M, "\tmodel:SetAttribute(\"DropPos\", spot)\n", ""),
    ("no DropRadius", M, "\tmodel:SetAttribute(\"DropRadius\", J.Radius)\n", ""),
    ("DropTime not the warning", M, "\tmodel:SetAttribute(\"DropTime\", warn)\n", "\tmodel:SetAttribute(\"DropTime\", 2)\n"),
    ("the body stays behind", M, "\t\tmodel:PivotTo(CFrame.lookAt(p, p + flat.Unit))\n", ""),
    ("a slam moves too", M, "\tif not slam then\n\t\t-- the body stands", "\tif true then\n\t\t-- the body stands"),
    ("no cooldown after a leap", M, "\trec._nextAttackAt = now + (slam and MC.AttackCooldown or math.max(LEAP.Cycle(L), LEAP.Num(rec._leapCycle, 0)))\n", ""),
    ("cycle shorter than the warning", M, "return math.max(LEAP.Num(L.Warn, 1) + 0.1, LEAP.Num(L.Cycle, MC.AttackCooldown))",
     "return LEAP.Num(L.Cycle, MC.AttackCooldown)"),
    ("mult ignores the cycle", M, "\treturn LEAP.Cycle(L) / math.max(0.1, MC.AttackCooldown)\n", "\treturn 1\n"),
    ("explicit mult ignored", M, "\tif m then return math.max(0, m) end\n", ""),
    # try
    ("no range limit", M, "\tif d > LEAP.Num(L.Range, 14) then return false end\n", ""),
    ("swings between leaps", M, "\tif d > MC.AttackRange then return false end -- between leaps out of reach", "\tif true then return false end -- between leaps out of reach"),
    ("slam every attack", M, "if rec._slamCount % math.max(1, math.floor(LEAP.Num(L.Every, 3))) ~= 0 then return false end", "local _ = rec._slamCount"),
    ("slams counted when not ready", M, "\t\tif not ready or d > MC.AttackRange then return false end\n", "\t\tif d > MC.AttackRange then return false end\n"),
    ("switch ignored", M, "if type(B) ~= \"table\" or B.Enabled == false or type(B.Kinds) ~= \"table\" then return nil end",
     "if type(B) ~= \"table\" or type(B.Kinds) ~= \"table\" then return nil end"),
    ("kind switch ignored", M, "return (type(L) == \"table\" and L.Enabled ~= false) and L or nil", "return type(L) == \"table\" and L or nil"),
    # config
    ("King range 30", C, "SlimeKing = { Mode = \"Leap\", Range = 14, Warn = 1, Height = 12 },",
     "SlimeKing = { Mode = \"Leap\", Range = 30, Warn = 1, Height = 12 },"),
    ("King warning 0.3 s", C, "SlimeKing = { Mode = \"Leap\", Range = 14, Warn = 1, Height = 12 },",
     "SlimeKing = { Mode = \"Leap\", Range = 14, Warn = 0.3, Height = 12 },"),
    ("Clatter slams every attack", C, "CaptainClatter = { Mode = \"Slam\", Every = 3, Warn = 1, Mult = 2 },",
     "CaptainClatter = { Mode = \"Slam\", Every = 1, Warn = 1, Mult = 2 },"),
    ("grace 0", C, "\tGrace = 0.5, YRange = 12, RetryDelay = 0.5,", "\tGrace = 0, YRange = 12, RetryDelay = 0.5,"),
    ("growth too small to land", C, "\tLeapGrow = 6, LeapGrowMax = 18,", "\tLeapGrow = 2, LeapGrowMax = 6,"),
]


def static() -> tuple[int, list[str]]:
    count, failures = 0, []

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    mon = read(SSS / "MonsterService.luau")
    section = between(mon, SECTION, NEXT)
    check("task.wait(" not in section and "wait(" not in section.replace("task.delay(", ""), "task.* only in LEAP")
    check("<const>" not in mon, "no <const>")
    check(mon.count("local LEAP = {}") == 1 and mon.find("local LEAP = {}") < mon.find("local function personalStep(")
          < mon.find("local function aiStep("), "LEAP is declared once, before personalStep / aiStep")
    ai = function_block(mon, "local function aiStep(")
    early = ai.find("if rec._leap then")
    check(0 <= early < ai.find("if rec.Owner then") and "hum:MoveTo(pos)" in ai[early:early + 60],
          "aiStep: during a landing it stands still (zone and personal monsters), before anything else moves it")
    hook = ai.find("if LEAP.Try(rec, best, bestD, now) then")
    check(0 <= ai.find("if alerting then return end") < hook < ai.find("local ranged = rec.Def.Ranged") < ai.find("if bestD <= MC.AttackRange then"),
          "aiStep: the landing rules come after the alert and before the ranged / melee branches")
    ps = function_block(mon, "local function personalStep(")
    check(0 <= ps.find("LEAP.Try(rec, info, d, now)") < ps.find("if d > PERSONAL_FOLLOW_RADIUS then"),
          "personalStep: a personal King leaps before its plain chase / swing")
    sp = function_block(mon, "function MonsterService.SpawnPersonal(")
    check("opts.LeapGrow" in sp and "rec._leapGrow, rec._leapGrowMax" in sp, "SpawnPersonal: opts.LeapGrow / LeapGrowMax")
    fk = read(SSS / "FirstKOService.luau")
    strike = function_block(fk, "local function strike(")
    check("local function strike(rec, target, mult)" in fk and "hum.MaxHealth * retryOf(target).Hit * mult" in strike
          and "hitBase(rec, target, mult)" in strike, "FirstKOService.strike takes the landing's mult (retry Hit x mult, plain x mult)")
    land = function_block(fk, "local function land(")
    check("e.Stage ~= \"First\"" not in land and "Config.BossLeap.Grace" in land, "both Kings' drops hit inside the circle (same Grace)")
    spawn = function_block(fk, "local function spawnKing(")
    check("opts.LeapGrow, opts.LeapGrowMax" in spawn and "model:SetAttribute(\"DropRadius\", num(FK.LandRadius, 10))" in spawn
          and "num(FK.FirstLeapAfter, 0.5)" in spawn, "spawnKing: the first King grows, DropRadius = LandRadius, Hold + FirstLeapAfter")
    check("cameFrom(rec, root.Position)" in strike, "the first KO gets up away from where the King leapt from")
    client = read(STARTER / "LandShadow.luau")
    for attr in ("DropAt", "DropTime", "DropRadius", "DropPos"):
        check(f"GetAttribute(\"{attr}\")" in client, f"game dev 1's LandShadow reads {attr}")
    return count, failures


SUITE = Suite(
    mark="BOSSLEAP",
    fixture=ROOT / "tools/fixtures/boss_leap_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-11/offline_dev2_boss_leap_2026-10-11.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-113 ①: Config.BossLeap.Kinds — SlimeKing Leap (Range 14, Warn 1, Height 12, cycle = AttackCooldown, x "
             "cycle / AttackCooldown), CaptainClatter Slam (every 3rd attack in swing reach, Warn 1, x2); a landing sets "
             "DropPos (Leap: the ground where the target stands, in its zone unless personal; Slam: its feet), DropRadius "
             "(LandShadow.Radius[kind] + a personal King's growth, clamped Min..MaxRadius), DropTime = Warn, DropFrom, "
             "DropHeight, then DropAt = now; a leaper moves onto the spot at once; Warn s later every valid player inside "
             "DropRadius - Grace (0.5) flat and YRange (12) is hit once (personal: its owner out of towns / water via "
             "its strike(rec, p, mult); else targetable: boss new-player rules, towns, zone, water); a slam bumps "
             "AttackSeq; a personal King that hit nobody grows LeapGrow up to LeapGrowMax (first KO King 6 / 18: 28 > "
             "the fastest walk); no ground = no leap, RetryDelay 0.5; between leaps in reach a leaper stands facing "
             "(never a swing).",
    limitations="MonsterService's aiStep / personalStep / SpawnPersonal and FirstKOService hooks are checked as source "
                "text (FirstKOService's strike / land / spawn run in test_first_ko_king); the AI loop, ground rays and "
                "CombatService are doubles; the circle, the fall and DropFrom / DropHeight drawing are game dev 1's client.",
)

if __name__ == "__main__":
    run(SUITE)
