"""A23-87 new kinds (게임성 개발 2, 2026-10-09), server side, offline.

Flower Slime (meadow, hides on the Salt flower patches until a player it may chase comes within Pop or it is hit, then
pops out: Hidden / PopAt for the client's small sparkle), Slingshot Goblin (woods) and Skeleton Archer (ruins, beside
a Skeleton Knight) with kid-safe ranged shots: a slow, big, telegraphed shot at where the target stood at the release,
dodged by stepping aside, the target only, the swing's town / zone / water rules; damage under the zone's melee kind.
KillCardService: a Flower Slime kill sometimes (Chance, once per 10 min a player) offers the ChoiceCard FlowerPatch.

Runs MonsterService's real A23-87 section (MOB3) with its real targetable() on engine doubles, the current Config and
KillCardService on tools/fixtures/dev2_kit.luau + tools/fixtures/mobs3_offline.luau with the installed official Luau
CLI. The aiStep / spawn / damage hooks are checked as source text. No Studio, network, DataStore or Roblox API calls;
mutations run on in-memory copies of the sources only.

Usage: py tools/test_mobs3.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-09/offline_dev2_mobs3_2026-10-09.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, between, function_block, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "MONSTER_SOURCE": SSS / "MonsterService.luau",
    "KILLCARD_SOURCE": SSS / "KillCardService.luau",
}
C, M, K = "CONFIG_SOURCE", "MONSTER_SOURCE", "KILLCARD_SOURCE"
SECTION = "------------------------------------------------------------------ A23-87 new kinds"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    mon = sources[M]
    out_y = re.search(r"^local OUT_Y = .*$", mon, re.M)
    if not out_y:
        raise ValueError("MonsterService OUT_Y missing; update the test extractor.")
    return {
        "CONFIG_SOURCE": sources[C],
        "UTIL_SOURCE": sources["UTIL_SOURCE"],
        "KILLCARD_SOURCE": sources[K],
        "MOB3_EXTRACT": (
            "local Config, Util, H = ...\n"
            "local MC = Config.Monsters\n"
            "local records, MOB3, FACE, REACT, S, MonsterService = H.records, H.MOB3, H.FACE, H.REACT, H.S, H.MonsterService\n"
            "local isPlayerInTown, warnThrottled, getGroundParams = H.isPlayerInTown, H.warnThrottled, H.getGroundParams\n"
            "local pickSpawnPoint, groundPoint, SEP, workspace = H.pickSpawnPoint, H.groundPoint, H.SEP, H.workspace\n"
            "local ReplicatedStorage = nil\n"
            "local WINDUP_AT_ATTR, ATTACK_SEQ_ATTR = \"WindupAt\", \"AttackSeq\"\n"
            + out_y.group(0) + "\n"
            + function_block(mon, "local function targetable(")
            + between(mon, SECTION, "local function aiStep(")
            + "\nreturn MOB3\n"),
    }


MUTATIONS = [
    # the shot
    ("a shot at once (no wind-up)", M, "\ttask.delay(math.max(0.1, num3(R.Windup, 0.9)), function()",
     "\ttask.delay(0, function()"),
    ("no cooldown", M, "\trec._nextAttackAt = now + math.max(0.5, num3(R.Cooldown, 3))\n", ""),
    ("two wind-ups at once", M, "\tif rec._windup ~= nil or now < rec._nextAttackAt then return end\n\trec._nextAttackAt = now + math.max(0.5",
     "\tif now < rec._nextAttackAt then return end\n\trec._nextAttackAt = now + math.max(0.5"),
    ("no WindupAt telegraph", M, "\tif rec.Model then rec.Model:SetAttribute(WINDUP_AT_ATTR, workspace:GetServerTimeNow()) end\n", ""),
    ("it walks while shooting", M, "\trec._goal = nil\n\trec.Humanoid:MoveTo(rec.Root.Position)\n\trec._inReach = true -- standing to shoot\n",
     "\trec._goal = nil\n\trec._inReach = true -- standing to shoot\n"),
    ("a shot at any range", M, "local tpos = R and MOB3.TargetPos(rec, target, num3(R.Range, 20) + REACT.WINDUP_LEEWAY)",
     "local tpos = R and MOB3.TargetPos(rec, target, nil)"),
    ("a dead monster shoots", M, "\tif not rec.Alive or records[rec.Id] ~= rec or rec._returning then return nil end\n", ""),
    ("no shot Fx", M, "pcall(MOB3.Net.Fx, nil, \"MonsterShot\"", "pcall(function() end, nil, \"MonsterShot\""),
    ("an instant shot", M, "local travel = Util.FlatDistance(from, tpos) / math.max(1, num3(R.Speed, 18))", "local travel = 0"),
    ("no dodge (homing)", M, "\tif Util.FlatDistance(p, to) > num3(R.Radius, 3) or math.abs(p.Y - to.Y) > 6 then return false end\n", ""),
    ("a tiny hit radius", M, "Util.FlatDistance(p, to) > num3(R.Radius, 3)", "Util.FlatDistance(p, to) > 0.5"),
    ("no town rule on landing", M, "\tif not targetable(rec, info) then return false end\n\tif S and S.CombatService then",
     "\tif S and S.CombatService then"),
    ("a dead target hit", M, "if not R or typeof(target) ~= \"Instance\" or target.Parent == nil or not Util.IsAlive(target) then return false end",
     "if not R or typeof(target) ~= \"Instance\" or target.Parent == nil then return false end"),
    ("no AttackSeq", M, "\trec.Model:SetAttribute(ATTACK_SEQ_ATTR, (type(seq) == \"number\" and seq or 0) + 1)\n", ""),
    ("stand goal on the far side", M, "\treturn Vector3.new(tpos.X, pos.Y, tpos.Z) + d.Unit * math.max(0, num3(stand, 15))",
     "\treturn Vector3.new(tpos.X, pos.Y, tpos.Z) - d.Unit * math.max(0, num3(stand, 15))"),
    # the ambush
    ("not hidden", M, "\trec._hidden = true\n\tif rec.Model then rec.Model:SetAttribute(\"Hidden\", true) end\n", ""),
    ("wakes at any distance", M, "\t\tif Util.FlatDistance(pos, info.Pos) <= pop and targetable(rec, info) then",
     "\t\tif targetable(rec, info) then"),
    ("a town player wakes it", M, "\t\tif Util.FlatDistance(pos, info.Pos) <= pop and targetable(rec, info) then",
     "\t\tif Util.FlatDistance(pos, info.Pos) <= pop then"),
    ("no PopAt", M, "\t\trec.Model:SetAttribute(\"PopAt\", workspace:GetServerTimeNow())\n", ""),
    ("no pop bark", M, "\tMonsterService.Moment:Fire(rec, \"Spot\")\nend", "end"),
    ("any ground is a flower patch", M, "\t\t\tif MOB3.MaterialAt(pt) == mat then return pt end", "\t\t\treturn pt"),
    ("partners stack on one knight", M, "\t\t\tif Util.FlatDistance(m, q) <= 10 then taken = true end", "\t\t\tlocal _ = q"),
    # kill cards
    ("every kill offers", K, "\t\t\t\tand Util.Random:NextNumber() < math.clamp(num(c.Chance), 0, 1) then", "\t\t\t\tthen"),
    ("no cooldown on cards", K, "\t\t\tif now - (mine[cardKind] or -math.huge) >= math.max(0, num(c.Cooldown, 600))\n",
     "\t\t\tif true\n"),
    ("a refused offer starts the cooldown", K, "\t\t\t\telseif opened == true then\n", "\t\t\t\telse\n"),
    ("any kind offers", K, "type(c.Kinds) == \"table\" and c.Kinds[info.Kind] == true\n", "type(c.Kinds) == \"table\"\n"),
    ("the card switch ignored", K, "if type(c) == \"table\" and c.Enabled ~= false and type(c.Kinds)", "if type(c) == \"table\" and type(c.Kinds)"),
    ("ranged kinds on before the client", C, "Config.Mobs3Ranged = false\n", "Config.Mobs3Ranged = true\n"),
    # config
    ("a fast shot", C, "Ranged = { Range = 22, Stand = 17, Windup = 0.9, Speed = 18,", "Ranged = { Range = 22, Stand = 17, Windup = 0.9, Speed = 40,"),
    ("archer hits as hard as a skeleton", C, "ZONE_ARCHER_DMG", "ZONE_ARCHER_DMG"),
    ("a thin shot", C, "Speed = 20, Radius = 3, Cooldown = 3.2 }", "Speed = 20, Radius = 1, Cooldown = 3.2 }"),
    ("cards every minute", C, "Kinds = { FlowerSlime = true }, Chance = 0.25, Cooldown = 600 },",
     "Kinds = { FlowerSlime = true }, Chance = 0.25, Cooldown = 60 },"),
]
# a placeholder entry above is replaced with a real one (kept the list readable)
MUTATIONS = [m for m in MUTATIONS if m[2] != "ZONE_ARCHER_DMG"] + [
    ("archer hits as hard as a skeleton", C, "SkeletonArcher = { Name = \"Skeleton Archer\", Short = \"Skeleton Archer\", Zone = \"SkeletonRuins\", Count = 3, HP = 380,\n\t\tDamage = 10,",
     "SkeletonArcher = { Name = \"Skeleton Archer\", Short = \"Skeleton Archer\", Zone = \"SkeletonRuins\", Count = 3, HP = 380,\n\t\tDamage = 14,"),
]


def static() -> tuple[int, list[str]]:
    count, failures = 0, []

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    mon = read(SSS / "MonsterService.luau")
    ai = function_block(mon, "local function aiStep(")
    check("if rec._hidden and not MOB3.Wake(rec, plist, pos) then" in ai, "aiStep: a hidden one waits until MOB3.Wake")
    ranged = ai.find("local ranged = rec.Def.Ranged")
    melee = ai.find("if bestD <= MC.AttackRange then")
    check(0 <= ranged < melee, "aiStep: the ranged branch comes before the melee swing")
    check("MOB3.Shoot(rec, best, now)" in ai and "MOB3.StandGoal(pos, best.Pos, ranged.Stand)" in ai,
          "aiStep: shoots in range, else walks to its stand point")
    spawn = function_block(mon, "local function spawnMonster(")
    check("MOB3.Spot(def, kind)) or pickSpawnPoint(def, kind)" in spawn and "MOB3.Hide(rec)" in spawn,
          "spawnMonster: the flower patch / partner spot first, hidden flower slimes")
    dmg = function_block(mon, "function MonsterService.DamageMonster(")
    check("if record._hidden then MOB3.Show(record) end" in dmg, "a hit pops a hidden one out")
    check(mon.count("local MOB3 = {}") == 1 and mon.find("local MOB3 = {}") < mon.find("local function spawnMonster("),
          "MOB3 is declared before its users")
    section = between(mon, SECTION, "local function aiStep(")
    check("Shake" not in section and "Sound" not in section, "the pop has no shake / sound on the server (client: a small sparkle)")
    main = read(SSS / "Main.server.luau")
    check(main.count('"KillCardService"') == 2, "Main lists KillCardService twice")
    start = main[main.find("local START_ORDER"):]
    check(0 <= start.find('"ChoiceCard"') < start.find('"KillCardService"') < start.find('"PlayerService"'),
          "KillCardService starts after ChoiceCard, before PlayerService")
    return count, failures


SUITE = Suite(
    mark="MOBS3",
    fixture=ROOT / "tools/fixtures/mobs3_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-09/offline_dev2_mobs3_2026-10-09.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-87: FlowerSlime (meadow, Ambush Salt / Pop 8: Hidden attribute until a player it may chase is within "
             "Pop or it is hit, then Hidden false + PopAt + a Spot bark), SlingshotGoblin (woods) and SkeletonArcher "
             "(ruins, PartnerOf SkeletonKnight: 4-8 studs from a knight without an archer) with Ranged { Range, Stand, "
             "Windup, Speed, Radius, Cooldown }: in range it stands, faces and winds up (WindupAt), then Fx MonsterShot "
             "{ Id, Kind, From, To, Speed, Radius, Travel } to all; after Travel s the target only is hit when still within "
             "Radius of To (Y within 6) and still a valid target; out of range at the release = no shot. Damage under the "
             "zone's melee kind. KillCards.FlowerPatch: a Flower Slime kill offers ChoiceCard FlowerPatch with Chance, at "
             "most once per 600 s a player (only an opened card starts the cooldown).",
    limitations="MonsterService's aiStep / spawnMonster / DamageMonster hooks are checked as source text; the AI loop, "
                "ground rays, CombatService and ChoiceCard are doubles; the client (shot drawing, pop sparkle, hidden "
                "nametag) is game dev 1's.",
)

if __name__ == "__main__":
    run(SUITE)
