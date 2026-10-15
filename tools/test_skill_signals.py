"""A23-116 skills18 server part (docs/design/skills18_2026-10-10.md "0. 18개 공통", 담당 row 게임성 개발 2), offline.

Runs the CURRENT tools/test_skills.py sources (Config, Util, CombatService, LootService, StoryQuestService, PvPService,
DamageWindow, SkillService, MonsterService and the unarmed suite's extracts) on tools/fixtures/dev2_combat_world.luau
with tools/fixtures/skill_signals_offline.luau, plus CombatService.luau / SkillService.luau as they were at BASE (read with
`git show`, never written) for the 'same numbers as before' comparison, with the installed official Luau CLI. No Studio,
network, DataStore or Roblox API calls. Mutations run on in-memory copies of the current sources only.

Usage: py tools/test_skill_signals.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-11/offline_dev2_skill_signals_2026-10-11.json (A23-126; was ..._2026-10-10.json)
"""
from __future__ import annotations

import subprocess

from dev2_offline import ROOT, SSS, Suite, function_block, read, run, strip_comments
from test_skills import FILES as SKILL_FILES, bindings as skill_bindings

# the last sources before the A23-116 server timing / signals (origin/main a1a74b45, 2026-10-10). Re-pin it only when
# CombatService / SkillService damage, heal, steal or pull / push code changes on purpose after this round
BASE = "a1a74b45"
FILES = dict(SKILL_FILES)
C, CO, SK = "CONFIG_SOURCE", "COMBAT_SOURCE", "SKILL_SOURCE"
_BASE_CACHE: dict[str, str] = {}


def base_source(rel: str) -> str:
    if rel not in _BASE_CACHE:
        proc = subprocess.run(["git", "show", f"{BASE}:{rel}"], cwd=ROOT, capture_output=True, timeout=60)
        if proc.returncode != 0:
            raise ValueError(f"git show {BASE}:{rel} failed; the 'same numbers' baseline is missing")
        _BASE_CACHE[rel] = proc.stdout.decode("utf-8-sig").replace("\r\n", "\n")
    return _BASE_CACHE[rel]


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = skill_bindings(sources)
    out["BASE_COMBAT_SOURCE"] = base_source("src/ServerScriptService/CombatService.luau")
    out["BASE_SKILL_SOURCE"] = base_source("src/ServerScriptService/SkillService.luau")
    return out


MUTATIONS = [
    # --- the pull / push at the contact time (SkillService.move)
    ("the pull / push at once (no contact wait)", SK, "\tif wait > 0 then\n\t\ttask.delay(wait, go)\n\telse\n\t\tgo()\n\tend\n",
     "\tgo()\n"),
    ("the slide waits a fixed 0.24 s", SK, "local wait = math.clamp(num(ctx.Contact), 0, 1)", "local wait = 0.24"),
    ("a dead monster still slides", SK,
     "if player.Parent == nil or not rec.Alive or not (rec.Root and rec.Root.Parent) then return end",
     "if player.Parent == nil or not (rec.Root and rec.Root.Parent) then return end"),
    ("a removed monster still slides", SK,
     "if player.Parent == nil or not rec.Alive or not (rec.Root and rec.Root.Parent) then return end",
     "if player.Parent == nil or not rec.Alive then return end"),
    ("a caster who left still pulls", SK,
     "if player.Parent == nil or not rec.Alive or not (rec.Root and rec.Root.Parent) then return end",
     "if not rec.Alive or not (rec.Root and rec.Root.Parent) then return end"),
    ("a Displace error escapes", SK, "local ok, err = pcall(ms.Displace, rec, mode, at, studs, player)",
     "local ok, err = true, ms.Displace(rec, mode, at, studs, player)"),
    ("the push one stud longer", SK, "mode, studs = \"Push\", num(def.Push)", "mode, studs = \"Push\", num(def.Push) + 1"),
    ("an auto push at once", SK, "local wait = math.clamp(num(ctx.Contact), 0, 1)",
     "local wait = ctx.Auto and 0 or math.clamp(num(ctx.Contact), 0, 1)"),
    # --- the origin: a pull toward the caster's spot at the contact, a push from the spot of the press
    ("a pull toward the press spot", SK, "\t\t\tat = root.Position\n", "\t\t\tat = from\n"),
    ("a push from the live spot", SK, "\t\tif mode == \"Pull\" then\n", "\t\tif true then\n"),
    ("a knocked-out caster still pulls", SK,
     "if not Util.IsAlive(player) or Util.GetCharacter(player) ~= character then return end",
     "if Util.GetCharacter(player) ~= character then return end"),
    ("a new character still pulls", SK,
     "if not Util.IsAlive(player) or Util.GetCharacter(player) ~= character then return end",
     "if not Util.IsAlive(player) then return end"),
    # --- the Skill packet's times
    ("no ContactDelay on Fx Skill", SK, "\t\tContactDelay = ctx.Contact, -- A23-116: s from the press (CombatService Kit.Motion)\n", ""),
    ("no LaunchDelay on Fx Skill", SK, "\t\tLaunchDelay = ctx.Launch,\n", ""),
    ("the field's Fx Skill without times", SK, "\t\tContactDelay = ctx.Contact, LaunchDelay = ctx.Launch, -- A23-116: like a Z / X resolve\n", ""),
    ("the pet tamer on the archer times", SK,
     "kit.Motion(slot, c.Id, Config.IsTamer(c.Id, fac) and Config.Tamer.SkillStyle or nil)", "kit.Motion(slot, c.Id, nil)"),
    ("auto casts without times", SK, "\tif type(kit.Motion) == \"function\" then\n",
     "\tif type(kit.Motion) == \"function\" and not isAuto then\n"),
    # --- the signals on Fx Skill / SkillTick
    ("no Healed on Fx Skill", SK, "\t\tHealed = healedIds, -- A23-116: UserIds whose HP really went up (the caster too, nearest 5 first)\n", ""),
    ("no Stole on Fx Skill", SK, "\t\tStole = stole, -- A23-116: HP the Horns life steal really gave the caster (0 = none)\n", ""),
    ("Fx Skill Stole always 0", SK, "\t\tStole = stole, -- A23-116: HP the Horns life steal really gave the caster (0 = none)\n",
     "\t\tStole = 0,\n"),
    ("no Healed on Fx SkillTick", SK, "\t\t\tHealed = sig.Healed, Stole = sig.Stole }) -- A23-116 signals of this tick",
     "\t\t\tStole = sig.Stole })"),
    ("no Stole on Fx SkillTick", SK, "\t\t\tHealed = sig.Healed, Stole = sig.Stole }) -- A23-116 signals of this tick",
     "\t\t\tHealed = sig.Healed })"),
    ("the field's Fx Skill without the signals", SK, "\t\tHealed = sig.Healed, Stole = sig.Stole, -- A23-116: the first tick's signals\n", ""),
    # --- damage unchanged (the 'same numbers' comparison)
    ("Z damage one more", SK, "Util.RoundDamage(CS.ComputeMonsterHit(player, false) * mult)\n\t\tfor _, m in plan.Monsters do",
     "Util.RoundDamage(CS.ComputeMonsterHit(player, false) * mult + 1)\n\t\tfor _, m in plan.Monsters do"),
    ("a field tick one more", SK, "Util.RoundDamage(CS.ComputeMonsterHit(player, false) * mult)\n\t\tfor _, m in mons do",
     "Util.RoundDamage(CS.ComputeMonsterHit(player, false) * mult + 1)\n\t\tfor _, m in mons do"),
    ("Q damage one more", CO, "local dealt = Util.RoundDamage(D * releaseMult)", "local dealt = Util.RoundDamage(D * releaseMult + 1)"),
    ("life steal x1.5", CO, "local want = SKILL.Fit(total * rate, room)", "local want = SKILL.Fit(total * rate * 1.5, room)"),
    ("Halo heal x1.5", CO, "local want = SKILL.Fit((skill.HaloHealPct or 0.10) * total, room)",
     "local want = SKILL.Fit((skill.HaloHealPct or 0.10) * 1.5 * total, room)"),
    # --- SKILL.Heal's Healed list (CombatService)
    ("Healed lists a full-HP ally", CO, "if amount > 0 then table.insert(got, ", "if want > 0 then table.insert(got, "),
    ("Healed without the caster", CO, "if amount > 0 then table.insert(got, ", "if a ~= player and amount > 0 then table.insert(got, "),
    ("Healed farthest first", CO, "table.sort(got, function(x, y) return x.D < y.D or (x.D == y.D and x.Id < y.Id) end)",
     "table.sort(got, function(x, y) return x.D > y.D or (x.D == y.D and x.Id > y.Id) end)"),
    ("the tie goes to the higher id", CO, "(x.D == y.D and x.Id < y.Id)", "(x.D == y.D and x.Id > y.Id)"),
    ("Healed in join order", CO, "\ttable.sort(got, function(x, y) return x.D < y.D or (x.D == y.D and x.Id < y.Id) end)\n", ""),
    ("Healed keeps everyone", CO, "HEALED_MAX = 5,", "HEALED_MAX = 99,"),
    ("Healed keeps 4", CO, "HEALED_MAX = 5,", "HEALED_MAX = 4,"),
    ("the heal for any side", CO, "if a.Parent and faction(a) == \"Halo\" and Util.IsAlive(a) then", "if a.Parent and Util.IsAlive(a) then"),
    ("Released.Healed gets the UserIds", CO, "\t\tHealed = healed,\n", "\t\tHealed = healedIds,\n"),
    ("no Healed on Fx Release", CO, "\t\tHealed = healedIds,\n\t\tStole = stole,\n\t})", "\t\tStole = stole,\n\t})"),
    ("no Stole on Fx Release", CO, "\t\tHealed = healedIds,\n\t\tStole = stole,\n\t})", "\t\tHealed = healedIds,\n\t})"),
    ("Stole = the HP asked, not gained", CO, "\tSKILL.Book(\"Steal\", player, player, amount)\n\treturn amount\n",
     "\tSKILL.Book(\"Steal\", player, player, amount)\n\treturn want\n"),
    # --- the per-slot times (CombatService TUNE.MOTION / SKILL.Motion)
    ("Kit.Motion: Q without its Release row", CO, "TUNE.MOTION[slot == \"Q\" and \"Release\" or slot]", "TUNE.MOTION[slot]"),
    ("Kit.Motion for any row (a swing)", CO, "(slot == \"Q\" or slot == \"Z\" or slot == \"X\") and TUNE.MOTION", "TUNE.MOTION"),
    ("Kit.Motion without the launch", CO, "\treturn m.Contact, m.Launch\n", "\treturn m.Contact, nil\n"),
    ("the Z row's archer contact 0.37", CO,
     "\t\tZ = {\n\t\t\tWarrior = { Contact = 0.24 },\n\t\t\tMage = { Launch = 0.35, Contact = 0.35 },\n\t\t\tArcher = { Launch = 0.18, Contact = 0.4 },",
     "\t\tZ = {\n\t\t\tWarrior = { Contact = 0.24 },\n\t\t\tMage = { Launch = 0.35, Contact = 0.35 },\n\t\t\tArcher = { Launch = 0.18, Contact = 0.37 },"),
    ("the X row's mage launch 0.24", CO,
     "\t\tX = {\n\t\t\tWarrior = { Contact = 0.24 },\n\t\t\tMage = { Launch = 0.35, Contact = 0.35 },",
     "\t\tX = {\n\t\t\tWarrior = { Contact = 0.24 },\n\t\t\tMage = { Launch = 0.24, Contact = 0.35 },"),
    ("the X row without the pet", CO,
     "\t\t\tArcher = { Launch = 0.18, Contact = 0.4 },\n\t\t\tPetDash = { Contact = 0.35 },\n\t\t},\n\t},\n",
     "\t\t\tArcher = { Launch = 0.18, Contact = 0.4 },\n\t\t},\n\t},\n"),
    # A23-126 heal fairness
    ("self heal at the friends' 30%", CO, "local capPct = a == player and (skill.HaloSelfHealCapPct or 0.03) or (skill.HaloHealCapPct or 0.30)",
     "local capPct = skill.HaloHealCapPct or 0.30"),
    ("ranged Q heals around the blast", CO, "\tif c.ReleaseCenter == \"Target\" then healAt, healR = pos, skill.HaloHealRadius or 12 end\n", ""),
    ("ranged Q heals around me with the blast radius", CO, "healAt, healR = pos, skill.HaloHealRadius or 12", "healAt, healR = pos, radius"),
    ("self cap 30% in Config", C, "\tHaloSelfHealCapPct = 0.03, HaloHealRadius = 12,", "\tHaloSelfHealCapPct = 0.30, HaloHealRadius = 12,"),
    ("old Star Fall line", C, "A big star falls on the closest monster. Heals you and your friends.", "A big star falls on the closest monster. Friends near it get healed."),
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
    release = function_block(combat, "function CombatService.Release(")
    check("Healed = healed," in release and "Healed = healedIds," in release and "Stole = stole," in release,
          "Release: Released keeps Healed = healed (Player objects); the Fx Release carries Healed = healedIds and Stole")
    check("local motion = TUNE.MOTION.Release[style or c.Id]" in release,
          "the Q times are still read from TUNE.MOTION.Release (the row Z / X copy)")
    heal = function_block(combat, "function SKILL.Heal(")
    check("return healed, ids" in heal and "return healed, {}" in heal, "SKILL.Heal: (others healed, UserIds) on every return")
    skill = strip_comments(read(SSS / "SkillService.luau"))
    move = function_block(read(SSS / "SkillService.luau"), "local function move(")
    check("task.delay(wait, go)" in move and "task.wait" not in skill, "the pull / push waits with task.delay (never a yield)")
    check(skill.count('"SkillTick",') == 1 and skill.count('"Skill", ') == 2,
          "one SkillTick sender, two Skill senders (resolve + startField)")
    for word in ("Net.Notify", "AddStat(", "MarketplaceService"):
        check(word not in skill, f"no new player text, score or sale in SkillService ({word})")
    # the client reads the same names (game dev 1's SkillFx.luau)
    client = read(ROOT / "src/StarterPlayer/StarterPlayerScripts/SkillFx.luau")
    for name in ("data.Healed", "data.Stole", "data.ContactDelay", "data.LaunchDelay"):
        check(name in client, f"SkillFx.luau reads {name}")
    return count, failures


SUITE = Suite(
    mark="SKILLSIG",
    fixture=ROOT / "tools/fixtures/skill_signals_offline.luau",
    world=ROOT / "tools/fixtures/dev2_combat_world.luau",
    out=ROOT / "docs/art/verification_2026-10-11/offline_dev2_skill_signals_2026-10-11.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-116 server part (skills18 §0, game dev 2): Fx Release (Q), Fx Skill (Z / X, also a field's first tick) "
             "and Fx SkillTick carry Healed = { UserId } (the Halo players whose HP this cast's heal really raised, the "
             "caster too, the nearest 5 to the heal centre first, ties by the lower id; {} = nobody) and Stole = number "
             "(the HP SKILL.Steal really gave the Horns caster; 0 at full HP, at the 3 s cap, for Halo / Neutral). "
             "Released.Healed is unchanged (the OTHER players healed, Player objects, no cap). Fx Skill carries "
             "ContactDelay / LaunchDelay from CombatService TUNE.MOTION.Z / .X (Kit.Motion(slot, class, style); for now "
             "the Q values: Warrior 0.24 / -, Mage 0.35 / 0.35, Archer 0.4 / 0.18, the pet tamer PetDash 0.35 / -). A "
             "pull / push (MonsterService.Displace) starts at that ContactDelay (task.delay; the damage, Released and "
             "the Fx stay at the press; auto casts too), skipped for a monster that died / was removed or a caster who "
             "left, errors pcall + warn; a pull goes toward the caster's root at the contact (none after a KO / a new "
             "character), a push away from the spot of the press (a hop's takeoff). Damage, every heal / steal asked and "
             "given, MP, MP steal, pull / push distance, taunt, slow and Guard numbers are identical to the sources at "
             f"{BASE} (9 kits + the 6 Halo / Horns kits with big HP so no cap binds; manual + auto, PvP on). Healed "
             "ties at the same distance go to the lower UserId.",
    limitations="The client side (SkillFx hearts / sparkles, the clip times) is game dev 1's; the real slide (Displace's "
                "CFrame loop) and the monster's walk during the 0.24-0.4 s wait are not run offline. The 'same numbers' "
                f"baseline is pinned at {BASE} (git show): re-pin BASE when that code changes on purpose.",
)

if __name__ == "__main__":
    run(SUITE)
