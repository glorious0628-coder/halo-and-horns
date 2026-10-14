"""SKL-2 class skills, first part (docs/design/skill_kit_beta_2026-10-06.md §1-§4, §8-1, §9; A23-49), offline.

Runs the CURRENT Config, Util, CombatService, LootService, StoryQuestService, PvPService, DamageWindow and SkillService
(whole modules) plus the ShopService / JusticeService extracts of tools/test_unarmed_start.py on
tools/fixtures/dev2_combat_world.luau with tools/fixtures/skills_offline.luau, and MonsterService.Displace as a chunk cut
from the current MonsterService.luau, with the installed official Luau CLI. No Studio, network, DataStore or Roblox API
calls; the auto-combat loop is stepped by hand. Mutations run on in-memory copies of the sources only.

Usage: py tools/test_skills.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-07/offline_dev2_skills_2026-10-07.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run, strip_comments
from test_unarmed_start import FILES as UNARMED_FILES, bindings as unarmed_bindings

FILES = dict(UNARMED_FILES)
FILES["WINDOW_SOURCE"] = SSS / "DamageWindow.luau"
FILES["SKILL_SOURCE"] = SSS / "SkillService.luau"
FILES["MONSTER_SOURCE"] = SSS / "MonsterService.luau"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = unarmed_bindings(sources)
    for key in ("WINDOW_SOURCE", "SKILL_SOURCE", "MONSTER_SOURCE"):
        out[key] = sources[key]
    return out


C, CO, SK, DW, M = "CONFIG_SOURCE", "COMBAT_SOURCE", "SKILL_SOURCE", "WINDOW_SOURCE", "MONSTER_SOURCE"

MUTATIONS = [
    # --- SkillService: the gap, the queue, the gates
    ("no gap between skills", SK, "local wait = num(K.GlobalGap, 0.5) - (os.clock() - s.LastAt)", "local wait = 0"),
    ("a press inside the gap is dropped (no queue)", SK,
     "return queue(player, s, slot, wait, hint) -- one queued press at a time", "return false -- one queued press at a time"),
    ("more than one queued press", SK, "\tif s.Queued ~= nil then return false end\n\ts.Queued = slot", "\ts.Queued = slot"),
    ("a queued press survives a new character", SK,
     "if player.Parent == nil or Util.GetCharacter(player) ~= character then return end", "if player.Parent == nil then return end"),
    ("slots ignored", SK, "if not flagOn(slot) or SLOT[slot] > slotsOf(player) then", "if not flagOn(slot) then"),
    ("ZEnabled / XEnabled ignored", SK, "if not flagOn(slot) or SLOT[slot] > slotsOf(player) then", "if SLOT[slot] > slotsOf(player) then"),
    ("no Z cooldown", SK, "\tif now < readyAt then\n\t\tif isAuto then return false end", "\tif false then\n\t\tif isAuto then return false end"),
    ("no MP check before the cast", SK, "if num(player:GetAttribute(\"Mana\"), 0) < cost then", "if false then"),
    ("Q cooldown answered by nobody", SK, "\t\tif left > 0 then\n\t\t\t-- 10/14", "\t\tif false then\n\t\t\t-- 10/14"),
    ("no 'No target' answer", SK, "if not first then return nil, \"NoTarget\" end", "if not first then return nil, nil end"),
    ("SkillReadyAtZ not written", SK, "\tplayer:SetAttribute(READY_ATTR[slot], Util.Now() + cd)\n", ""),
    # --- shapes and damage
    ("the band has no width", SK, "math.abs(d.X * dir.Z - d.Z * dir.X) <= half", "true"),
    ("the band has no length", SK, "return along >= 0 and along <= len and", "return along >= 0 and"),
    ("the band also hits behind", SK, "return along >= 0 and along <= len and", "return along <= len and"),
    ("the band never turns to the aimed monster", SK,
     "local dir = flatDir(aim and (aim.E.Pos - pos) or ctx.Root.CFrame.LookVector)", "local dir = flatDir(ctx.Root.CFrame.LookVector)"),
    ("the chain jumps any distance", SK, "for _, m in kit.MonstersNear(ctx.Player, at, jump) do -- nearest first",
     "for _, m in kit.MonstersNear(ctx.Player, at, 1000) do -- nearest first"),
    ("the chain hits a monster twice", SK, "\t\t\tif not used[m.Rec] then\n", "\t\t\tif true then\n"),
    ("one link more than Hits", SK, "while #chain < hits do", "while #chain < hits + 1 do"),
    ("Z damage without Mult", SK, "Util.RoundDamage(CS.ComputeMonsterHit(player, false) * mult)\n\t\tfor _, m in plan.Monsters do",
     "Util.RoundDamage(CS.ComputeMonsterHit(player, false))\n\t\tfor _, m in plan.Monsters do"),
    ("an auto cast pulls", SK, "if num(def.Pull) > 0 and not ctx.Auto then", "if num(def.Pull) > 0 then"),
    ("no pull", SK, "mode, studs = \"Pull\", num(def.Pull)", "mode, studs = nil, 0"),
    ("no push", SK, "mode, studs = \"Push\", num(def.Push)", "mode, studs = nil, 0"),
    # --- players, heal, steal
    ("PvPZX ignored", SK, "PvP = not isAuto and K.PvPZX == true and PVP[fac] == true", "PvP = not isAuto and PVP[fac] == true"),
    ("an auto Z hits players", SK, "PvP = not isAuto and K.PvPZX == true", "PvP = K.PvPZX == true"),
    ("Z player damage outside the window", SK,
     "kit.Fit(CS.ComputePvPHit(player, vp) * mult, kit.Room(\"Hit\", player, vp, capPct * vHum.MaxHealth))",
     "CS.ComputePvPHit(player, vp) * mult"),
    ("Z player damage not booked", SK, "\t\t\t\tkit.Book(\"Hit\", player, vp, applied)\n", ""),
    ("no heal from Z", SK, "\t\thealed, healedIds = kit.Heal(player, ctx.Pos, TUNE.HealRadius, total)",
     "\t\thealed, healedIds = 0, {}"),
    ("heal radius 20", SK, "HealRadius = 12,", "HealRadius = 20,"),
    ("no steal from Z", SK, "\t\tstole = kit.Steal(player, total) -- A23-116: Fx Stole\n", "\t\tstole = 0\n"),
    ("Released without Slot", SK, "\t\tSlot = ctx.Slot,\n\t\tStacks = 0, -- legacy event compatibility\n",
     "\t\tStacks = 0, -- legacy event compatibility\n"),
    ("Released Auto always false", SK, "\t\tAuto = ctx.Auto,\n\t\tPerfect = false,", "\t\tAuto = false,\n\t\tPerfect = false,"),
    # --- auto rules
    ("auto Z ignores Min", SK, "\tif n < num(a.Min, 1) then return false end\n", ""),
    ("auto Z ignores big monsters", SK, "\t\t\tif d and (d.Boss or num(d.Scale, 1) >= TUNE.BigScale) then return true end\n", ""),
    ("auto Chain Bolt always before Q", SK, "\t\t\tif qReady then return false end\n", ""),
    ("auto Q always before Chain Bolt", SK, "if not (spread and n >= num(a.BeforeQIfSpread, 2)) then", "if true then"),
    # --- slots
    ("slots never saved", SK, "\tS.PlayerService.SetStat(player, \"SkillSlots\", want)\n", ""),
    ("slots can go down", SK, "\tif want <= have then return end\n", "\tif want == have then return end\n"),
    # A23-71: none before Lv5, Q Lv5 / Z Lv15 / X Lv25
    ("Q from the start again", SK, 'math.floor(num(player:GetAttribute("SkillSlots"), 0)), 0, 3)',
     'math.floor(num(player:GetAttribute("SkillSlots"), 0)), 1, 3)'),
    ("SkillSlotsFor ignores rebirths", C, "\tif (tonumber(rebirths) or 0) >= 1 then return 3 end\n", ""),
    ("SkillSlotsFor counts one slot too many", C, "local unlock, lv, n = Config.Skills.Unlock or {}, tonumber(level) or 1, 0",
     "local unlock, lv, n = Config.Skills.Unlock or {}, tonumber(level) or 1, 1"),
    ("SkillSlotsFor: a slot one level early", C, "if lv >= (tonumber(unlock[slot]) or math.huge) then n += 1 end",
     "if lv + 1 >= (tonumber(unlock[slot]) or math.huge) then n += 1 end"),
    ("Config: Q at Lv1 again", C, "Unlock = { Q = 5, Z = 15, X = 25 }", "Unlock = { Q = 1, Z = 15, X = 25 }"),
    ("Config: Z at Lv5 again", C, "Unlock = { Q = 5, Z = 15, X = 25 }", "Unlock = { Q = 5, Z = 5, X = 25 }"),
    ("Config: a new save starts with Q", C, "\t\tSkillSlots = 0,\n", "\t\tSkillSlots = 1,\n"),
    ("a rebirth opens nothing", SK, 'num(player:GetAttribute("Level"), 1), num(player:GetAttribute("Rebirths")))',
     'num(player:GetAttribute("Level"), 1), 0)'),
    ("the unlock notice with the flag off", SK, "\t\tif slot and flagOn(slot) then\n", "\t\tif slot then\n"),
    ("the unlock notice at join", SK, "function(player) catchUp(player, false) end)", "function(player) catchUp(player, true) end)"),
    ("no catch-up at level up", SK, "\tconnect(\"ProgressionService\", \"LeveledUp\", function(player) catchUp(player, true) end)\n", ""),
    ("a real respawn keeps the Z cooldown", SK, "\t\t\ts.ReadyAt, s.Queued = {}, nil\n", "\t\t\ts.Queued = nil\n"),
    ("a cosmetic respawn resets the Z cooldown", SK, "if cosmetic or not isPlayer(player) then return end",
     "if not isPlayer(player) then return end"),
    # --- the remote
    ("UseSkill takes extra arguments", SK, "if select(\"#\", ...) ~= 0 or type(slot)", "if type(slot)"),
    ("UseSkill without a rate limit", SK,
     "\tif not Util.RateLimit(player, \"UseSkill\", num(Config.RateLimits.UseSkill, 0.1)) then return end\n", ""),
    ("auto combat does not yield to a skill press", SK,
     "\tS.CombatService.Kit.NoteManual(player) -- auto combat yields to my own presses\n", ""),
    # --- DamageWindow
    ("the window never forgets", DW, "if now - e.T < DamageWindow.Seconds then", "if true then"),
    ("an entry lasts past 3 s (<=)", DW, "if now - e.T < DamageWindow.Seconds then", "if now - e.T <= DamageWindow.Seconds then"),
    ("Room below 0", DW, "return math.max(0, capHP - used(list, os.clock()))", "return capHP - used(list, os.clock())"),
    ("bad numbers booked", DW, "or type(n) ~= \"number\" or n ~= n or n <= 0 or n == math.huge then return end",
     "or type(n) ~= \"number\" then return end"),
    ("a leaver stays in the book", DW, "\t\tleaving:Connect(function(player) DamageWindow.Forget(player) end)\n", ""),
    ("Forget one way only", DW, "\tfor _, byTo in book do byTo[player] = nil end\n", ""),
    # --- CombatService (Q through the window, the alias, auto)
    ("Q back to the per-cast cap", CO,
     "local raw = SKILL.Fit(D * releaseMult, SKILL.Room(\"Hit\", player, vp, capPct * vHum.MaxHealth))",
     "local raw = math.min(D * releaseMult, capPct * vHum.MaxHealth)"),
    ("Q damage not booked", CO, "\t\t\t\t\tSKILL.Book(\"Hit\", player, vp, applied)\n", ""),
    ("heal per cast (no window)", CO,
     "local room = SKILL.Room(\"Heal\", player, a, capPct * aHum.MaxHealth)",
     "local room = capPct * aHum.MaxHealth"),
    ("steal per cast (no window)", CO,
     "local room = SKILL.Room(\"Steal\", player, player, lifestealCapBase(player, hum) * (perks.LifestealCapPct or 0))",
     "local room = lifestealCapBase(player, hum) * (perks.LifestealCapPct or 0)"),
    ("Released without Slot Q", CO, "\t\tSlot = \"Q\", -- SKL-2: Z / X casts (SkillService) fire this signal with their own slot\n", ""),
    ("Release reports nothing", CO, "\treturn true -- SKL-2: the cast went off (SkillService keeps the shared gap from here)\n", ""),
    ("the old Release remote skips SkillService", CO,
     "\t\tskills.Cast(player, \"Q\", false, hint) -- SKL-2: the shared 0.5 s gap / one queued press / the refusal words\n",
     "\t\tCombatService.Release(player, false, hint)\n"),
    ("auto never tries Z", CO, "local okZ, cast = pcall(skills.AutoCast, p)", "local okZ, cast = true, false"),
    ("auto Q skips the gap", CO, "\t\t\tskills.Cast(p, \"Q\", true) -- the shared gap\n", "\t\t\tCombatService.Release(p, true)\n"),
    ("a skill press is not noted", CO, "function SKILL.NoteManual(player)\n\tlastManualAt[player] = os.clock()\nend",
     "function SKILL.NoteManual(player)\nend"),
    # --- A23-61 server aim for skills (검수 2026-10-07)
    ("Z never aims behind", SK, "local any = kit.MonstersNear(ctx.Player, ctx.Pos, reach)[1]", "local any = nil"),
    ("a turned Z still hits players", SK, "ctx.TurnTo, ctx.PvP = any.Pos, false", "ctx.TurnTo = any.Pos"),
    ("a turned Z does not turn the root", SK,
     "\tif ctx.TurnTo then kit.TurnTo(ctx.Root, ctx.Pos, ctx.TurnTo) end -- A23-61 server aim: face the monster I aimed at\n", ""),
    ("Q never aims behind", CO, "local nearQ = monstersNear(player, pos, range)[1]", "local nearQ = nil"),
    ("a turned Q blast hits players", CO, "\tif not isAuto and not turnedQ then\n", "\tif not isAuto then\n"),
    ("auto Q only at the cone", CO,
     "\tlocal inReach = monstersNear(p, pos, reach) -- A23-61 server aim: any direction (Release turns to it)\n",
     "\tlocal inReach = monstersNear(p, pos, reach)\n\tif c.ReleaseCenter == \"Target\" then inReach = aimed(inReach, root, c.AimCone) end\n"),
    # --- MonsterService.Displace
    ("a pull never stops in front", M, "\tif mode == \"Pull\" then dist = math.min(dist, gap - DISPLACE.Stop) end\n", ""),
    ("size ignored", M, "local dist = studs / math.max(1, record._scale or 1)", "local dist = studs"),
    ("a boss moves", M, "\tif type(def) == \"table\" and def.Boss then return 0 end\n", ""),
    ("the leash ignored", M,
     "\n\t\t\t\tand (typeof(record.Home) ~= \"Vector3\" or Util.FlatDistance(dest, record.Home) <= MC.LeashRadius)", ""),
    ("the zone edge ignored", M, "\t\t\tok = insideZone(zone, dest, ZONE_MOVE_INSET)\n", "\t\t\tok = true\n"),
    ("water ignored", M, "ok = (g ~= nil or noHit) and not workspace:Raycast", "ok = not workspace:Raycast"),
    ("walls ignored", M, " and not workspace:Raycast(pos, delta + dir * 0.5, getShoveParams())", ""),
    ("no shorter steps", M, "Steps = { 1, 0.75, 0.5, 0.25 }, HopDrop = 8 }", "Steps = { 1 }, HopDrop = 8 }"),
    ("someone else's personal monster moves", M,
     "\tif record.Owner and record.Owner ~= player then return 0 end -- A5-C2\n", ""),
    ("a push pulls", M, "local dir = mode == \"Pull\" and toCaster.Unit or -toCaster.Unit", "local dir = toCaster.Unit"),
    ("a knocked-out zone monster moves", M,
     "\tif record.Owner == nil and (here ~= record.ZoneId or not zone) then return 0 end\n", ""),
    # --- Config
    ("no UseSkill rate limit", C, "\tUseSkill = 0.1, -- SKL-2", "\tUseSkill = 0, -- SKL-2"),
    ("SkillSlots not mirrored", C, "\t\t\"SkillSlots\", -- SKL-2: the SkillBar shows these slots\n", ""),
    # user 10/14 "서버가 거절을 안 하게": the air cast, the cooldown's press buffer, silent refusals
    ("no air cast (refused again)", SK, "\t\tif not isAuto and why == \"NoTarget\" then return airCast(ctx) end\n", ""),
    ("auto casts into the air", SK, "\t\tif not isAuto and why == \"NoTarget\" then return airCast(ctx) end\n",
     "\t\tif why == \"NoTarget\" then return airCast(ctx) end\n"),
    ("the air cast spends MP", SK, "\tctx.Air = true\n\tresolve(ctx,",
     "\tS.VitalsService.TrySpendMana(ctx.Player, num(def.MP), true)\n\tctx.Air = true\n\tresolve(ctx,"),
    ("the air cast takes the gap", SK, "\ts.AirAt = now + num(K.GlobalGap, 0.5)\n",
     "\ts.AirAt = now + num(K.GlobalGap, 0.5)\n\ts.LastAt = now\n"),
    ("the air cast counts as a skill use", SK, "\tif ctx.Air then return end -- never a skill use", "\tif false then return end -- never a skill use"),
    ("no air spam guard", SK, "\tif now < (s.AirAt or -math.huge) then return false end\n", ""),
    ("no Z / X press buffer", SK, "\t\tif readyAt - now <= pressBuffer() then return queue(", "\t\tif false then return queue("),
    ("no Q press buffer", SK, "\t\t\tif left <= pressBuffer() then return queue(player, s, \"Q\"", "\t\t\tif false then return queue(player, s, \"Q\""),
    ("the buffer is a whole second", SK, "\treturn math.max(0, num(K.PressBuffer, 0.35))\n", "\treturn 1\n"),
    ("NoMP said again", SK, "\tif num(player:GetAttribute(\"Mana\"), 0) < cost then return false end -- the screen blocks it",
     "\tif num(player:GetAttribute(\"Mana\"), 0) < cost then press(player, slot, \"NoMP\") return false end -- the screen blocks it"),
    ("Locked said again", SK, "\tif not flagOn(slot) or SLOT[slot] > slotsOf(player) then return false end",
     "\tif not flagOn(slot) or SLOT[slot] > slotsOf(player) then if not isAuto then press(player, slot, \"Locked\") end return false end"),
    ("PressBuffer 0.5", C, "\tPressBuffer = 0.35, AirReach = 12,", "\tPressBuffer = 0.5, AirReach = 12,"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    main = read(SSS / "Main.server.luau")
    for name in ("DamageWindow", "SkillService"):
        check(main.count(f'"{name}"') == 2, f"Main lists {name} in INIT_ORDER and START_ORDER")
    start = main[main.find("local START_ORDER"):]
    start = start[:start.find("\n}")]
    check(0 <= start.find('"DamageWindow"') < start.find('"SkillService"') < start.find('"PlayerService"'),
          "DamageWindow, then SkillService, start before PlayerService")
    net = read(SHARED / "Net.luau")
    check(net.count('"UseSkill"') == 1, "Net.Names has UseSkill once")
    skill = strip_comments(read(SSS / "SkillService.luau"))
    check("Config.Skills.Defs" not in skill and "K.Defs" not in skill, "skill numbers only through Config.SkillDef (SKL-1)")
    for word in ("AddStat(", "Honor", "Infamy", "Robux", "MarketplaceService"):
        check(word not in skill, f"skills change no score and sell nothing ({word})")
    check("Net.Notify" not in skill, "refusals go to the button (Fx SkillPress), not a toast")
    combat = read(SSS / "CombatService.luau")
    release = function_block(combat, "function CombatService.Release(")
    check("applyLifesteal(" not in release and "SKILL.Steal(player, total)" in release
          and "SKILL.Heal(player, healAt, healR, total)" in release, "Q heals / steals through the window")
    swing = function_block(combat, "function CombatService.Swing(")
    check("applyLifesteal(player, perks, totalDealt)" in swing, "basic swings keep their own per-swing lifesteal")
    return count, failures


SUITE = Suite(
    mark="SKILLS",
    fixture=ROOT / "tools/fixtures/skills_offline.luau",
    world=ROOT / "tools/fixtures/dev2_combat_world.luau",
    out=ROOT / "docs/art/verification_2026-10-07/offline_dev2_skills_2026-10-07.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="SKL-2 (A23-49): UseSkill(slot) -> SkillService.Cast: GlobalGap 0.5 s between any two skills (a manual "
             "press inside it queued once, an auto cast waits), refusals before MP with Fx SkillPress { Slot, Result }. "
             "Q = CombatService.Release (returns true, Released.Slot = \"Q\"); Z shapes: Line (band Len x Width toward "
             "the nearest aimed target, else ahead) and Chain (Range, Jump, Hits, no repeats; no target = NoTarget). "
             "Damage D x Mult once a target; pull (manual) / push via MonsterService.Displace (stop 3 in front, / body "
             "scale, bosses never, zone rect + leash + ground + walls, shorter steps). DamageWindow: 3 s per pair, player "
             "damage 35% (kaiju 8%), Halo heal 30% an ally, Horns steal 3% - Q and Z share it; players only with PvPZX "
             "and a manual cast. Slots (A23-71): SkillSlots 0..3 = Config.SkillSlotsFor (Q Lv5 / Z Lv15 / X Lv25, all "
             "after a rebirth), never lowered, Fx SkillUnlocked (Q always, Z / X only while the slot's flag is on); no "
             "skill before Lv5 (manual, the old Release remote and auto). Auto: Z first by its rule (Min / OrBig / BeforeQIfSpread), never pulls.",
    limitations="X shapes (Field / Roar / Hop), Guard / Slow / Taunt / MP steal and the X-first auto order are SKL-3: "
                "tools/test_skills_x.py (SK1 / SK2 in tools/test_town_quests.py). The client parts (SkillBar buttons, SkillFx looks, the refusal shake / words, the unlock page) are "
                "game dev 1's and image dev's. Displace's slide itself (the CFrame loop) is not run offline.",
)

if __name__ == "__main__":
    run(SUITE)
