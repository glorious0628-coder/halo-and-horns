"""SKL-3 X skills (docs/design/skill_kit_beta_2026-10-06.md §1-§4, §10; A23-71 X at Lv25), offline.

Runs the CURRENT Config, Util, CombatService, LootService, StoryQuestService, PvPService, DamageWindow and SkillService
(the tools/test_skills.py bindings) on tools/fixtures/dev2_combat_world.luau with tools/fixtures/skills_x_offline.luau,
and the real MonsterService hooks (Taunt / Slow / HopReach cut out with Displace, DamageMonster's one hit a cast,
NATURAL.Pace's slow), VitalsService.AddMana and ZoneService.AllowMove as chunks cut from the current sources, with the
installed official Luau CLI. No Studio, network, DataStore or Roblox API calls; a field's ticks and the auto-combat loop
are stepped by hand. Mutations run on in-memory copies of the sources only.

Usage: py tools/test_skills_x.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-07/offline_dev2_skills_x_2026-10-07.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SSS, Suite, function_block, read, run, strip_comments
from test_skills import FILES as SKILL_FILES, bindings as skill_bindings

FILES = dict(SKILL_FILES)
FILES["VITALS_SOURCE"] = SSS / "VitalsService.luau"
FILES["ZONE_SOURCE"] = SSS / "ZoneService.luau"
C, CO, SK, M, V, Z = "CONFIG_SOURCE", "COMBAT_SOURCE", "SKILL_SOURCE", "MONSTER_SOURCE", "VITALS_SOURCE", "ZONE_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = skill_bindings(sources)
    vit = sources[V]
    out["VITALS_EXTRACT"] = (
        "local Config, Util, Players, S, states, TUNE = ...\nlocal VitalsService = {}\n"
        + function_block(vit, "local function publish(")
        + function_block(vit, "local function ready(")
        + function_block(vit, "function VitalsService.AddMana(")
        + "\nreturn VitalsService\n")
    zone = sources[Z]
    out["ZONE_EXTRACT"] = (
        "local Config, Util, AC, move, zoneIds, lastGateNotify, lastPadTouch, channels = ...\nlocal ZoneService = {}\n"
        + function_block(zone, "local function acNum(")
        + function_block(zone, "local function checkMove(")
        + function_block(zone, "local function cleanup(")
        + function_block(zone, "function ZoneService.AllowMove(")
        + "\nreturn { Check = checkMove, Allow = ZoneService.AllowMove, Cleanup = cleanup }\n")
    return out


MUTATIONS = [
    # --- Roar
    ("Roar hits outside its radius", SK, "\tlocal r = num(def.Radius, 12)\n\tlocal plan = { Center = pos, Radius = r,",
     "\tlocal r = num(def.Radius, 12) + 4\n\tlocal plan = { Center = pos, Radius = r,"),
    ("no taunt", SK, "local ok, did = pcall(ms.Taunt, m.Rec, ctx.Player, num(def.TauntSec, 4))", "local ok, did = true, false"),
    ("taunt only within the hit radius", SK,
     "for _, m in S.CombatService.Kit.MonstersNear(ctx.Player, ctx.Pos, num(def.TauntRadius, 16)) do",
     "for _, m in S.CombatService.Kit.MonstersNear(ctx.Player, ctx.Pos, num(def.Radius, 12)) do"),
    ("the Taunt switch ignored", SK, "if K.Taunt ~= false and type(ms.Taunt) == \"function\" then",
     "if type(ms.Taunt) == \"function\" then"),
    ("a refused taunt is counted", SK, "if ok and did then n += 1 end", "if ok then n += 1 end"),
    ("no self Guard", SK, "\t\tif guard(ctx.Player, def.SelfGuard, def.GuardSec) then\n", "\t\tif false then\n"),
    ("a weaker Guard replaces a stronger one", SK, "\tif live and g.Pct > pct then return false end\n", ""),
    ("the same Guard never extended", SK, "\tif live and g.Pct == pct then untilAt = math.max(untilAt, g.Until) end\n", ""),
    ("Guard for any faction", SK, "if a.Parent and factionOf(a) == \"Halo\" and Util.IsAlive(a) then",
     "if a.Parent and Util.IsAlive(a) then"),
    ("friends guarded from anywhere", SK, "if r and Util.FlatDistance(r.Position, center) <= radius then table.insert(out, a) end",
     "if r then table.insert(out, a) end"),
    ("GuardOf past its time", SK, "\tif not g or os.clock() >= g.Until then return 0 end\n", "\tif not g then return 0 end\n"),
    ("a real respawn keeps the Guard", SK, "\t\tclearGuard(player) -- SKL-3: a new life starts unguarded\n", ""),
    ("GuardUntil not published", SK, "\tp:SetAttribute(\"GuardUntil\", Util.Now() + (untilAt - now))\n", ""),
    ("no MP steal cap", SK, "local give = math.min(math.floor(num(n)), num(K.MPStealCap, 20) - (ctx.Stolen or 0))",
     "local give = math.floor(num(n))"),
    ("MP steal counts the asked, not the got", SK, "\tctx.Stolen = (ctx.Stolen or 0) + got\n\treturn got\n",
     "\tctx.Stolen = (ctx.Stolen or 0) + give\n\treturn give\n"),
    ("no MP steal", SK, "if num(def.MPSteal) > 0 and monstersHit > 0 then st.MP = stealMP(ctx, num(def.MPSteal) * monstersHit) end", ""),
    # --- Field
    ("a field may aim at a player", SK, "\tctx.PvP = false -- a field never hits players (§1-4)\n", ""),
    ("the field never goes ahead", SK, "local center = aim and aim.E.Pos or (pos + flatDir(ctx.Root.CFrame.LookVector) * num(def.Ahead, 10))",
     "local center = aim and aim.E.Pos or pos"),
    ("the field never ends", SK, "\tf.Left -= 1\n", ""),
    ("one tick only", SK, "\ttask.delay(tick, fieldTick, player, f)\n", ""),
    ("ticks stop after the second", SK, "\ttask.delay(f.Tick, fieldTick, player, f)\n", ""),
    ("each tick its own cast id", SK, "local killed, applied = kit.HitMonster(rec, dealt, player, false, f.Ctx.CastId)",
     "local killed, applied = kit.HitMonster(rec, dealt, player, false, nil)"),
    ("no slow", SK, "pcall(S.MonsterService.Slow, rec, num(def.Slow), slowSec)", "local _ = slowSec"),
    ("a killed monster is slowed", SK, "if not killed and num(def.Slow) > 0 and type(S.MonsterService.Slow) == \"function\" then",
     "if num(def.Slow) > 0 and type(S.MonsterService.Slow) == \"function\" then"),
    ("no friend Guard in the circle", SK, "\tguardFriends(f.Ctx, f.Center, f.Radius, guardSec, st)\n", ""),
    ("no MP steal a tick", SK, "if num(def.MPStealTick) > 0 and n > 0 then st.MP = stealMP(f.Ctx, num(def.MPStealTick) * n) end", ""),
    ("a KO keeps the field", SK, "\t\tendField(player, \"Died\")\n", ""),
    ("a zone change keeps the field", SK, "if f and newZone ~= f.Zone then endField(player, \"Zone\") end", "local _ = f"),
    ("the same zone ends the field", SK, "if f and newZone ~= f.Zone then endField(player, \"Zone\") end",
     "if f then endField(player, \"Zone\") end"),
    ("a class change keeps the field", SK, "\tconnect(\"ClassService\", \"ClassChanged\", function(player)\n\t\tforgetQueue(player)\n\t\tendField(player, \"Changed\")\n",
     "\tconnect(\"ClassService\", \"ClassChanged\", function(player)\n\t\tforgetQueue(player)\n"),
    ("a kaiju keeps the field", SK, "\t\tand not TUNE.Kaiju[S.CombatService.Kit.Kaiju(player)]\nend", "\nend"),
    ("a new character keeps the field", SK, "Util.IsAlive(player) and Util.GetCharacter(player) == f.Character", "Util.IsAlive(player)"),
    ("a leaver's field says SkillEnd", SK, "\tif why ~= \"Leave\" then\n", "\tif true then\n"),
    ("two fields at once", SK, "\tendField(player, \"New\")\n", ""),
    ("Fields off still ticks", SK, "local burst = K.Fields == false", "local burst = false"),
    ("the burst without the 5 ticks", SK, "local mult = num(def.TickMult, 1.5) * (burst and count or 1)",
     "local mult = num(def.TickMult, 1.5)"),
    ("the burst slows like a tick", SK, "local slowSec = burst and TUNE.BurstSlow or tick + TUNE.SlowPad", "local slowSec = tick + TUNE.SlowPad"),
    ("no slow pad", SK, "SlowPad = 0.5,", "SlowPad = 0,"),
    # 검수 2026-10-07: a field that hits only from its second tick still counts once, at its end, with its best tick
    ("a late field never reports at its end", SK, "\t\tfieldDone(f)\n\t\treturn\n", "\t\treturn\n"),
    ("an early end drops the late report", SK, "\t\tfieldDone(f)\n\tend\nend", "\tend\nend"),
    ("the late report = the first hitting tick (the old rule)", SK,
     "\tif f.Late then f.Best, f.Sum = math.max(f.Best, n), f.Sum + total end\n",
     "\tif f.Late and n > 0 then f.Late = false; fieldReleased(f, total, n) end\n"),
    ("the late report = the last tick", SK, "f.Best, f.Sum = math.max(f.Best, n), f.Sum + total",
     "f.Best, f.Sum = n, f.Sum + total"),
    ("the late Total = the last tick's damage", SK, "f.Best, f.Sum = math.max(f.Best, n), f.Sum + total",
     "f.Best, f.Sum = math.max(f.Best, n), total"),
    ("a field that hit at once reports again at its end", SK, "f.Late, f.Best, f.Sum = n == 0 and not burst, 0, 0",
     "f.Late, f.Best, f.Sum = not burst, 0, 0"),
    # --- Hop
    ("a hop with the grudge sack", SK, "if sack or TUNE.Kaiju[kit.Kaiju(player)] then return nil, \"TooHeavy\" end",
     "if TUNE.Kaiju[kit.Kaiju(player)] then return nil, \"TooHeavy\" end"),
    ("a kaiju hops", SK, "if sack or TUNE.Kaiju[kit.Kaiju(player)] then return nil, \"TooHeavy\" end",
     "if sack then return nil, \"TooHeavy\" end"),
    ("a 2.5 stud hop", SK, "\t\tif reach < TUNE.HopMin then return nil, \"CantHop\" end\n", "\t\tif reach <= 0 then return nil, \"CantHop\" end\n"),
    ("a hop forward", SK, "local back = -flatDir(ctx.Root.CFrame.LookVector)", "local back = flatDir(ctx.Root.CFrame.LookVector)"),
    ("the hop ignores walls", SK, "local reach = type(ms.HopReach) == \"function\" and num(ms.HopReach(pos, back, num(def.Hop, 10))) or 0",
     "local reach = num(def.Hop, 10)"),
    ("no AllowMove", SK, "if type(zs.AllowMove) == \"function\" then pcall(zs.AllowMove, player, plan.Hop + TUNE.HopSlack, 1) end", ""),
    ("AllowMove without the slack", SK, "pcall(zs.AllowMove, player, plan.Hop + TUNE.HopSlack, 1)", "pcall(zs.AllowMove, player, plan.Hop, 1)"),
    ("no Hop Fx", SK, "local ok, err = pcall(Net.Fx, player, \"Hop\", { To = plan.To, T = num(def.HopTime, 0.25) })",
     "local ok, err = true, nil"),
    ("MoveSkills ignored", SK, "\tif K.MoveSkills ~= false then\n\t\tlocal grudge", "\tif true then\n\t\tlocal grudge"),
    ("friends guarded around the spot I left", SK, "guardFriends(ctx, plan.To or ctx.Pos, ", "guardFriends(ctx, ctx.Pos, "),
    ("auto hops", SK, "if isAuto and (type(def.Auto) ~= \"table\" or def.Auto.Never) then return false end",
     "if isAuto and type(def.Auto) ~= \"table\" then return false end"),
    # --- auto
    ("auto never casts X", SK,
     "\tif K.XEnabled == true and slotsOf(player) >= SLOT.X and SkillService.Cast(player, \"X\", true) then return true end\n", ""),
    # (no 'auto X with XEnabled off' mutation: SkillService.Cast refuses a switched-off slot by itself, an equivalent mutant)
    ("auto Roar ignores Min", SK, "if #kit.MonstersNear(ctx.Player, ctx.Pos, num(a.Radius, 16)) >= num(a.Min, 3) then return true end",
     "if #kit.MonstersNear(ctx.Player, ctx.Pos, num(a.Radius, 16)) >= 1 then return true end"),
    ("auto Roar without the low-HP rule", SK,
     "return hum ~= nil and hum.MaxHealth > 0 and hum.Health / hum.MaxHealth < num(a.LowHP)",
     "return false and hum ~= nil and hum.MaxHealth > 0 and hum.Health / hum.MaxHealth < num(a.LowHP)"),
    ("auto Roar low HP at any distance", SK, "and #kit.MonstersNear(ctx.Player, ctx.Pos, num(a.LowHPRadius, 10)) > 0",
     "and #kit.MonstersNear(ctx.Player, ctx.Pos, num(a.Radius, 16)) > 0"),
    ("auto field for one monster", SK, "return #kit.MonstersNear(ctx.Player, plan.Center, num(a.Radius, 12)) >= num(a.Min, 2)",
     "return #kit.MonstersNear(ctx.Player, plan.Center, num(a.Radius, 12)) >= 1"),
    # --- CombatService
    ("Guard on every hit", CO,
     "if attacker == nil and type(sourceKind) == \"string\" and Config.MonsterTypes[sourceKind] ~= nil and S.SkillService",
     "if S.SkillService"),
    ("Guard on a player's hit", CO,
     "if attacker == nil and type(sourceKind) == \"string\" and Config.MonsterTypes[sourceKind] ~= nil and S.SkillService",
     "if type(sourceKind) == \"string\" and Config.MonsterTypes[sourceKind] ~= nil and S.SkillService"),
    ("no Guard", CO, "\t\tif g > 0 then amount = amount * (1 - math.clamp(g, 0, 0.9)) end\n", ""),
    ("the cast id dropped", CO, "local killed = S.MonsterService.DamageMonster(rec, dealt, player, crit, castId)",
     "local killed = S.MonsterService.DamageMonster(rec, dealt, player, crit)"),
    # --- MonsterService (cut out)
    ("one hit a cast ignored", M, "\t\tif castId == nil or record._castOf[player] ~= castId then\n", "\t\tif true then\n"),
    ("a cast id hit never counts", M, "\t\tif castId == nil or record._castOf[player] ~= castId then\n", "\t\tif castId == nil then\n"),
    ("a boss taunted", M, "\tif type(def) == \"table\" and def.Boss then return false end\n\tlocal now = os.clock()\n\tif record._tauntBy",
     "\tlocal now = os.clock()\n\tif record._tauntBy"),
    ("a personal monster taunted", M, "if type(record) ~= \"table\" or not record.Alive or record.Owner ~= nil then return false end",
     "if type(record) ~= \"table\" or not record.Alive then return false end"),
    ("a taunt taken over", M, "\tif record._tauntBy and record._tauntBy ~= player and now < (record._tauntUntil or 0) then return false end\n", ""),
    ("a taunt of any length", M, "record._tauntBy, record._tauntUntil = player, now + math.min(seconds, 10)",
     "record._tauntBy, record._tauntUntil = player, now + seconds"),
    ("a boss slowed fully", M, "\tif type(def) == \"table\" and def.Boss then mult = 1 - (1 - mult) / 2 end\n", ""),
    ("the weaker slow wins", M, "record._slowMult = running and math.min(record._slowMult or 1, mult) or mult", "record._slowMult = mult"),
    ("a slow never extended", M, "record._slowUntil = math.max(running and record._slowUntil or 0, now + math.min(seconds, 10))",
     "record._slowUntil = running and record._slowUntil or now + math.min(seconds, 10)"),
    ("slow unclamped", M, "\tmult = math.clamp(mult, 0.1, 1)\n", ""),
    ("Pace ignores the slow", M, "* pace * ramp * arrive * slow\n", "* pace * ramp * arrive\n"),
    ("hop through walls", M, "if (g ~= nil or noHit) and level and not workspace:Raycast(from, delta + dir * 0.5, getShoveParams()) then",
     "if (g ~= nil or noHit) and level then"),
    ("hop off a ledge", M, "local level = g == nil or base == nil or math.abs(g.Y - base.Y) <= DISPLACE.HopDrop", "local level = true"),
    ("hop out of the zone", M, "\t\tif Config.ZoneAt(dest).Id == here then\n", "\t\tif true then\n"),
    ("hop into water", M, "if (g ~= nil or noHit) and level and", "if level and"),
    ("HopReach past 40", M, "studs ~= studs or studs <= 0 or studs > 40 then return 0 end", "studs ~= studs or studs <= 0 then return 0 end"),
    ("no shorter hops", M, "\tfor _, part in DISPLACE.Steps do\n\t\tlocal delta = dir * (studs * part)", "\tfor _, part in { 1 } do\n\t\tlocal delta = dir * (studs * part)"),
    # --- VitalsService.AddMana / ZoneService.AllowMove (cut out)
    ("AddMana past MaxMana", V, "st.Mana = math.min(TUNE.MaxMana, before + amount)", "st.Mana = before + amount"),
    ("AddMana when not ready", V, "\tif not ready(player) then return 0 end\n", ""),
    ("AddMana takes NaN", V, "if type(amount) ~= \"number\" or amount ~= amount or amount <= 0 or amount == math.huge then return 0 end",
     "if type(amount) ~= \"number\" then return 0 end"),
    ("AddMana not published", V, "\tif st.Mana <= before then return 0 end\n\tpublish(player, st)\n", "\tif st.Mana <= before then return 0 end\n"),
    ("the move check ignores AllowMove", Z, "\tif extra and now < extra.Until then allowFlat += extra.Studs end -- SKL-3 Hop (AllowMove)\n", ""),
    ("AllowMove forever", Z, "if extra and now < extra.Until then allowFlat", "if extra then allowFlat"),
    ("AllowMove uncapped", Z, "move.extra[player] = { Studs = math.min(studs, 30), Until = os.clock() + math.min(seconds, 2) }",
     "move.extra[player] = { Studs = studs, Until = os.clock() + seconds }"),
    ("AllowMove takes NaN", Z, "if not studs or studs ~= studs or studs <= 0 or seconds ~= seconds or seconds <= 0 then return end",
     "if not studs then return end"),
    ("cleanup keeps the allowance", Z, "\tmove.extra[player] = nil\nend", "end"),
    # --- Config
    ("Config: Rage Roar steals 50", C, "\t\t\t\t\tMPSteal = 5 } },\n\t\t},\n\t\tMage = {", "\t\t\t\t\tMPSteal = 50 } },\n\t\t},\n\t\tMage = {"),
    ("Config: no MP steal cap", C, "GlobalGap = 0.5, MPStealCap = 20,", "GlobalGap = 0.5, MPStealCap = 999,"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    monster = read(SSS / "MonsterService.luau")
    ai = function_block(monster, "local function aiStep(")
    taunt = ai.find("if rec._tauntUntil and now < rec._tauntUntil then")
    search = ai.find("if best == nil and now >= rec._noAggroUntil then")
    check(0 <= taunt < search and "local tinfo = findInfo(plist, rec._tauntBy)" in ai
          and "if tinfo and targetable(rec, tinfo) then best, bestD = tinfo, Util.FlatDistance(pos, tinfo.Pos) end" in ai,
          "aiStep: a taunted monster targets its taunter first (while still a valid target), then the nearest player")
    skill = strip_comments(read(SSS / "SkillService.luau"))
    for word in ("AddStat(", "Honor", "Infamy", "Robux", "MarketplaceService"):
        check(word not in skill, f"X skills change no score and sell nothing ({word})")
    check("Net.Notify" not in skill, "X refusals go to the button (Fx SkillPress TooHeavy / CantHop), not a toast")
    check(skill.count('"SkillEnd",') == 1 and skill.count('"SkillTick",') == 1 and skill.count('Net.Fx, player, "Hop",') == 1,
          "one sender each for Fx SkillEnd, SkillTick and Hop (Hop to the caster only)")
    zone = read(SSS / "ZoneService.luau")
    check("function ZoneService.AllowMove(" in zone and "move.extra[player] = nil" in function_block(zone, "local function cleanup("),
          "ZoneService.AllowMove exists and cleanup forgets it")
    vitals = read(SSS / "VitalsService.luau")
    check("function VitalsService.AddMana(" in vitals, "VitalsService.AddMana exists")
    return count, failures


SUITE = Suite(
    mark="SKILLSX",
    fixture=ROOT / "tools/fixtures/skills_x_offline.luau",
    world=ROOT / "tools/fixtures/dev2_combat_world.luau",
    out=ROOT / "docs/art/verification_2026-10-07/offline_dev2_skills_x_2026-10-07.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="SKL-3 X (monster fights only for every status; XEnabled stays off until the 10/20 check, X at Lv25): Roar "
             "(r12 x2, Taunt r16 4 s via MonsterService.Taunt, my Guard 40% 6 s, Halo friends r16 20%, Horns +5 MP a "
             "monster hit, the anvil look for the blacksmith); Field (a circle r12 at the aimed monster within 35 or 10 "
             "ahead, a tick every 1 s for 5 s at x1.5 with one cast id, Slow x0.5 for tick + 0.5 s, Halo friends inside "
             "20% for tick + 0.1 s, Horns 2 MP a monster a tick; one field a player; it ends on a KO / zone / class / "
             "faction change / kaiju / new character (Fx SkillEnd { UserId, Slot, Why }), quietly on leaving; never "
             "players; Fields off = one x7.5 burst with a 3 s slow); Hop (back HopReach of 10, under 3 'CantHop', a sack "
             "or kaiju 'TooHeavy', both before MP; ZoneService.AllowMove(hop + 2, 1 s); Fx Hop { To, T } to the caster; "
             "the wind r7 x3 push 6; Halo friends r12 of the landing 20% 4 s; Horns +5 MP; never auto; MoveSkills off = "
             "the wind in place). MP steal at most 20 a cast. Guard: CombatService.DamagePlayer cuts a monster's hit only "
             "(GuardOf, the larger wins, the same extends, a real respawn clears; GuardPct / GuardUntil). Auto: X -> Z -> Q "
             "(Roar 3 within 16 or HP < 50% with one within 10; Field 2 inside the circle). MonsterService: Taunt (no "
             "boss / personal / someone else's live taunt, <= 10 s), Slow (boss half, strongest stays, <= 10 s, Pace), "
             "HopReach (zone, water, walls, ledges over 8, the Displace steps), DamageMonster castId (one hit a cast).",
    limitations="The client side (SkillFx circles / roar / hop movement, the HP bar shield, SkillBar X) is game dev 1's "
                "and image dev's; the hop's real character move, the monsters' real walk under Slow / Taunt (aiStep is "
                "checked statically) and the live AnalyticsService are not run offline. SK1 / SK2 and the SkillHit Slot "
                "filter are in tools/test_town_quests.py; the next-goal line in tools/test_onboarding.py.",
)

if __name__ == "__main__":
    run(SUITE)
