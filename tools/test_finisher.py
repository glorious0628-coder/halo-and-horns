"""The King Slime finisher card (게임성 개발 2, 2026-10-08), server side, offline.

docs/design/king_finisher_2026-10-08.md (rpg_success_analysis_2026-10-08 §4-3 #9, 검수 kid-safe cut). A King Slime
kill stays the same kill for everyone; a paid contributor with an accepted MANUAL hit (swing / Q / Z pressed by hand,
never auto combat) within the ContributorWindow also gets a card only they see: Fx "FinisherCard", c->s "FinisherPick"
(id, "Help" | "Tickle") - the open card, its Id, within Seconds + Grace, once - and Fx "FinisherEnd". Help = Jelly (a
full bag pays the rest at its sell price), Tickle = bank gold "Finisher" (never 2x), the same size. My side's pick:
+1 inside the ONE daily cap (Deeds, A23-86); the other side's: -1 (A23-58, never below 0); Neutral: the gift only.
Not picked / left = None. Metric FinisherPick (Halo | Horns | None, my faction).

Runs the CURRENT Config, Util, CombatService, SkillService, DamageWindow, LootService, StoryQuestService (the combat
world of tools/test_skills.py), MonsterService's REAL DamageMonster + killRecord (cut out), Deeds and
FinisherService on tools/fixtures/dev2_kit.luau + tools/fixtures/dev2_combat_world.luau with
tools/fixtures/finisher_offline.luau and the installed official Luau CLI. No Studio, network, DataStore or Roblox API
calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_finisher.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-08/offline_dev2_finisher_2026-10-08.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, between, function_block, read, run, strip_comments
from test_skills import FILES as SKILL_FILES, bindings as skill_bindings

FILES = dict(SKILL_FILES)
FILES["FINISHER_SOURCE"] = SSS / "FinisherService.luau"
FILES["DEEDS_SOURCE"] = SSS / "Deeds.luau"
C, CO, SK, M = "CONFIG_SOURCE", "COMBAT_SOURCE", "SKILL_SOURCE", "MONSTER_SOURCE"
F, D = "FINISHER_SOURCE", "DEEDS_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = skill_bindings(sources)
    out["FINISHER_SOURCE"] = sources[F]
    out["DEEDS_SOURCE"] = sources[D]
    mon = sources[M]
    # MonsterService's REAL kill: DamageMonster + killRecord, on the world's MonsterService table (helpers from H)
    out["KILL_SOURCE"] = (
        "local Config, Util, MC, MonsterService, H = ...\n"
        "local records = H.records\n"
        "local updateBar, deathPop, factionOf, removePersonalRef = H.updateBar, H.deathPop, H.factionOf, H.removePersonalRef\n"
        "local markHurt, zoneIdOf, scheduleRespawn, warnThrottled = H.markHurt, H.zoneIdOf, H.scheduleRespawn, H.warnThrottled\n"
        + between(mon, "local function killRecord(rec)", "-- A15: pain reaction for clients")
        + function_block(mon, "function MonsterService.DamageMonster(") + "\n"
        + "return killRecord\n")
    return out


MUTATIONS = [
    # --- MonsterService: the manual mark and the kill's info.Manual
    ("manual hits never marked", M, "\t\tif manual == true then\n\t\t\trecord._manualAt = record._manualAt or {}\n",
     "\t\tif false then\n\t\t\trecord._manualAt = record._manualAt or {}\n"),
    ("auto hits marked manual", M, "\t\tif manual == true then\n\t\t\trecord._manualAt = record._manualAt or {}\n",
     "\t\tif true then\n\t\t\trecord._manualAt = record._manualAt or {}\n"),
    ("Manual ignores the window", M, "i.Manual = manualAt[e.Player] ~= nil and now - manualAt[e.Player] <= window",
     "i.Manual = manualAt[e.Player] ~= nil"),
    ("the kill keeps the manual hits", M, "rec._contributors, rec._hits, rec._dmg, rec._share, rec._manualAt = {}, {}, {}, {}, {}",
     "rec._contributors, rec._hits, rec._dmg, rec._share = {}, {}, {}, {}"),
    ("a refused hit marked manual", M, "\tif record.Owner == nil and player and zoneIdOf(player) ~= record.ZoneId then return false end",
     "\tif record.Owner == nil and player and zoneIdOf(player) ~= record.ZoneId then\n"
     "\t\tif manual == true then record._manualAt = record._manualAt or {}; record._manualAt[player] = os.clock() end\n"
     "\t\treturn false\n\tend"),
    # --- CombatService / SkillService: who passes `manual`
    ("a manual swing passes false", CO, "damageMonster(rec, dealt, player, crit, nil, isManual)",
     "damageMonster(rec, dealt, player, crit, nil, false)"),
    ("an auto swing passes true", CO, "damageMonster(rec, dealt, player, crit, nil, isManual)",
     "damageMonster(rec, dealt, player, crit, nil, true)"),
    ("Q always manual", CO, "damageMonster(m.Rec, dealt, player, nil, nil, not isAuto)",
     "damageMonster(m.Rec, dealt, player, nil, nil, true)"),
    ("Q never manual", CO, "damageMonster(m.Rec, dealt, player, nil, nil, not isAuto)",
     "damageMonster(m.Rec, dealt, player, nil, nil, false)"),
    ("damageMonster drops manual", CO, "DamageMonster(rec, dealt, player, crit, castId, manual == true)",
     "DamageMonster(rec, dealt, player, crit, castId, false)"),
    ("Z always manual", SK, "kit.HitMonster(rec, dealt, player, false, ctx.CastId, not ctx.Auto)",
     "kit.HitMonster(rec, dealt, player, false, ctx.CastId, true)"),
    ("Z never manual", SK, "kit.HitMonster(rec, dealt, player, false, ctx.CastId, not ctx.Auto)",
     "kit.HitMonster(rec, dealt, player, false, ctx.CastId, false)"),
    # --- FinisherService: who gets a card
    ("any monster gives a card", F, "or F.Kinds[info.Kind] ~= true then return end", "then return end"),
    ("auto-only kills give a card", F, "if type(info) ~= \"table\" or info.Manual ~= true then return end",
     "if type(info) ~= \"table\" then return end"),
    ("two cards at once", F, "if CARD.Open[player] or player.Parent ~= Players then return false end",
     "if player.Parent ~= Players then return false end"),
    ("card ids never rise", F, "local id = (CARD.Serial[player] or 0) + 1", "local id = 1"),
    # --- the pick remote
    ("any id picks", F, "if not card or card.Id ~= id then return end", "if not card then return end"),
    ("extra args accepted", F, "local function onPick(player, id, option, ...)\n\tif select(\"#\", ...) ~= 0 then return end\n",
     "local function onPick(player, id, option, ...)\n"),
    ("any option accepted", F, "if type(id) ~= \"number\" or id ~= id or (option ~= \"Help\" and option ~= \"Tickle\") then return end",
     "if type(id) ~= \"number\" or id ~= id then return end"),
    ("no rate limit", F, "if not Util.RateLimit(player, \"FinisherPick\", num(Config.RateLimits.FinisherPick, 0.3)) then return end", ""),
    ("late picks accepted", F, "\tif os.clock() > card.Ends + math.max(0, num(F.Grace, 1)) then return end -- the timer ends it as \"None\"\n", ""),
    ("no network grace", F, "\tif os.clock() > card.Ends + math.max(0, num(F.Grace, 1)) then return end",
     "\tif os.clock() > card.Ends then return end"),
    ("picked twice", F, "\tif CARD.Open[player] ~= card then return end\n\tCARD.Open[player] = nil\n", "\tCARD.Open[player] = nil\n"),
    ("the card never times out", F, "\ttask.delay(seconds + math.max(0, num(F.Grace, 1)), function()\n\t\tfinish(player, card, nil)\n\tend)\n", ""),
    ("leaving keeps the card", F, "\t\t\tlocal ok, err = pcall(finish, player, card, nil)\n", "\t\t\tlocal ok, err = true, nil\n"),
    # --- gifts
    ("Tickle pays double", F, "return 0, math.max(0, math.floor(num(c.Tickle.Gold)))", "return 0, 2 * math.max(0, math.floor(num(c.Tickle.Gold)))"),
    ("a full bag loses the rest", F, "return given, (n - given) * math.max(0, math.floor(num(item and item.Sell or c.Help.Worth)))", "return given, 0"),
    ("a scroll's full bag pays nothing (no Worth)", F, "num(item and item.Sell or c.Help.Worth)", "num(item and item.Sell)"),
    ("every boss gets the King Slime's card", F,
     "\tlocal c = type(F.Cards) == \"table\" and F.Cards[kind] or nil\n",
     "\tlocal c = type(F.Cards) == \"table\" and F.Cards.SlimeKing or nil\n"),
    ("a GrantItem error is not caught", F, "local ok, res = pcall(S.LootService.GrantItem, player, id, n)",
     "local ok, res = true, S.LootService.GrantItem(player, id, n)"),
    ("gold from the pocket", F, "S.ProgressionService.AddBankGold(player, gold, \"Finisher\")",
     "S.ProgressionService.AddBankGold(player, gold, \"Monster\")"),
    ("the shown gold ignores the return", F, "gold = type(added) == \"number\" and added or gold", "gold = gold"),
    # --- points
    ("the pick's points not through Deeds", F, "local stat, change, mine, down = S.Deeds.Add(player, SIDE[option], points())",
     "local stat, change, mine, down = \"None\", 0, false, false"),
    ("the card's preview not from Deeds", F, "\treturn S.Deeds.Preview(player, SIDE[option], points())",
     "\treturn \"None\", 0, false"),
    ("my side's pick ignores the cap", D, "\t\tlocal got = Deeds.Take(player, n)\n", "\t\tlocal got = n\n"),
    ("no off-side drop", D, "\t\tS.PlayerService.SetStat(player, stat, have - take)\n", ""),
    ("off-side drops below 0", D, "\tlocal take = math.min(have, n)\n", "\tlocal take = n\n"),
    ("Neutral scores", D, "\tif f == \"Halo\" or f == \"Horns\" then return f end\n\treturn nil\n",
     "\tif f == \"Halo\" or f == \"Horns\" then return f end\n\treturn \"Horns\"\n"),
    ("the sides swapped", F, "local SIDE = { Help = \"Good\", Tickle = \"Evil\" }", "local SIDE = { Help = \"Evil\", Tickle = \"Good\" }"),
    ("no rank-down line", D, "\t\tdown = rankOf(f, have - take) < rankOf(f, have)\n", "\t\tdown = false\n"),
    # A23-130: the 'points full' line is off; putting it back must fail
    ("the 'points full' line back", F,
     "if down then notify(player, f == \"Halo\" and STORY.RankDownHalo or STORY.RankDownHorns, \"info\") end\n\t\tend\n",
     "if down then notify(player, f == \"Halo\" and STORY.RankDownHalo or STORY.RankDownHorns, \"info\") end\n"
     "\t\telseif mine and change <= 0 and points() > 0 then\n\t\t\tnotify(player, TXT.HintFull, \"info\")\n\t\tend\n"),
    ("no off-side line", F, "\t\tif stat ~= \"None\" and not mine then\n", "\t\tif false then\n"),
    ("the card shows points past the cap", D, "return stat, math.min(n, Deeds.Left(player)), true", "return stat, n, true"),
    ("the card shows a drop below 0", D, "return stat, -math.min(ownStat(player, stat), n), false", "return stat, -n, false"),
    # --- results, signal, metric
    ("no FinisherEnd", F, "\tif player.Parent == Players then fx(player, \"FinisherEnd\", out) end\n", ""),
    ("no Picked signal", F, "\tFinisherService.Picked:Fire(player, out.Pick, card.Kind)\n", ""),
    ("metric sides swapped", F, "local METRIC = { Help = \"Halo\", Tickle = \"Horns\" }", "local METRIC = { Help = \"Horns\", Tickle = \"Halo\" }"),
    ("no metric", F, "\tmetric(player, option)\n", ""),
    ("no reward line", F, "\t\tif #parts > 0 then notify(player, table.concat(parts, \" · \"), \"reward\", \"None\") end", "\t\tlocal _ = parts"),
    ("the pick line plays QuestDone", F, "\"reward\", \"None\") end -- the pick's own sound", "\"reward\") end -- the pick's own sound"),
    ("the sound never reaches Notify", F, "pcall(Net.Notify, player, text, kind, nil, sound)", "pcall(Net.Notify, player, text, kind)"),
    # A23-130: no zero / lean line at the score floor; putting it back must fail
    ("the zero line back", F,
     "\t\t\t\tnotify(player, string.format(f == \"Halo\" and STORY.OffSideHalo or STORY.OffSideHorns, -change), \"info\")\n\t\t\tend\n",
     "\t\t\t\tnotify(player, string.format(f == \"Halo\" and STORY.OffSideHalo or STORY.OffSideHorns, -change), \"info\")\n"
     "\t\t\telse\n\t\t\t\tnotify(player, STORY.OffSideHaloZero, \"info\")\n\t\t\tend\n"),
    ("hint Full and Zero swapped", F, "\treturn mine and \"Full\" or \"Zero\"\n", "\treturn mine and \"Zero\" or \"Full\"\n"),
    ("no Neutral hint", F, "\tif stat == \"None\" then return \"Neutral\" end\n", ""),
    ("a hint on a scoring option", F, "\tif score ~= 0 then return nil end\n", ""),
    # --- the deeds ledger as the card uses it (its own suite: test_choice_card)
    ("the day never resets", D, "\tif b.Day ~= day then b.Day, b.N = day, 0 end\n", ""),
    ("the cap never fills", D, "local give = math.min(n, math.max(0, perDay() - b.N))", "local give = n"),
    ("Take never books", D, "\tb.N += give\n", ""),
    # --- 검수 2026-10-09: Clatter's free riders (MonsterService's real kill)
    ("free riders get nothing", M, "\t\t\telseif minorShare > 0 and (rec._dmg[p] or 0) > 0 then\n\t\t\t\ttable.insert(minors, p)\n", "\t\t\telseif false then\n"),
    ("free riders paid in full", M, "\t\ti.XP, i.Gold = info.XP * minorShare, info.Gold * minorShare\n", ""),
    ("free riders get war points", M, "\t\ti.WarPoints, i.WarShare = 0, 0\n", ""),
    ("free riders not marked Minor", M, "\t\ti.Minor = true\n", ""),
    ("Clatter pays from 0.5%", C, "RewardMinDamageFrac = 0.02, MinorShare = 0.15,", "RewardMinDamageFrac = 0.005, MinorShare = 0.15,"),
    # --- Config
    ("20 s to pick", C, "\tSeconds = 10,\n\tGrace = 1,\n", "\tSeconds = 20,\n\tGrace = 1,\n"),
    ("2 points a pick", C, "\tGrace = 1,\n\tPoints = 1,\n", "\tGrace = 1,\n\tPoints = 2,\n"),
    ("3 Jelly (not the same size)", C, "Help = { Item = \"Jelly\", N = 2 }, Tickle = { Gold = 4 } },", "Help = { Item = \"Jelly\", N = 3 }, Tickle = { Gold = 4 } },"),
    ("the Slime Prince gives a card too", C, "\tKinds = { SlimeKing = true, CaptainClatter = true },",
     "\tKinds = { SlimeKing = true, CaptainClatter = true, BigSlime = true },"),
    ("the card on the Slime Prince instead", C, "\tKinds = { SlimeKing = true, CaptainClatter = true },",
     "\tKinds = { BigSlime = true, CaptainClatter = true },"),
    ("cap 50", C, "Config.Deeds = {\n\tPerDay = 6,", "Config.Deeds = {\n\tPerDay = 50,"),
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
    for name in ("Deeds", "FinisherService"):
        check(main.count(f'"{name}"') == 2, f"Main lists {name} in INIT_ORDER and START_ORDER")
    check('"ScoreBudget"' not in main and not (SSS / "ScoreBudget.luau").exists(), "ScoreBudget is retired (Deeds is the cap)")
    start = main[main.find("local START_ORDER"):]
    start = start[:start.find("\n}")]
    check(0 <= start.find('"Deeds"') < start.find('"PlayerService"')
          and 0 <= start.find('"FinisherService"') < start.find('"PlayerService"'), "both start before PlayerService")
    check('key == "Finisher"' in main and "S.FinisherService.DebugOffer(player)" in main, "Studio DebugCommand Finisher")
    net = read(SHARED / "Net.luau")
    check(net.count('"FinisherPick"') == 1, "Net.Names has FinisherPick once")
    fin = strip_comments(read(SSS / "FinisherService.luau"))
    check(re.findall(r'fx\(player, "(\w+)"', fin) == ["FinisherEnd", "FinisherCard"], "Fx only FinisherCard / FinisherEnd")
    check(re.findall(r'AddBankGold\(player, gold, "(\w+)"\)', fin) == ["Finisher"] and "AddCarriedGold" not in fin,
          "the card's gold: bank, source Finisher, one call")
    check("GrantFame" not in fin and "RankingService" not in fin and "CreditFame" not in fin,
          "the points never reach the weekly ranking (AddStat / SetStat only)")
    check(re.findall(r'T\.Custom, player, "(\w+)"', fin) == ["FinisherPick"], "one metric event: FinisherPick")
    check("MarketplaceService" not in fin and "Robux" not in fin, "nothing sold")
    combat = read(SSS / "CombatService.luau")
    swing = function_block(combat, "function CombatService.Swing(")
    release = function_block(combat, "function CombatService.Release(")
    check("damageMonster(rec, dealt, player, crit, nil, isManual)" in swing, "a swing passes isManual")
    check("damageMonster(m.Rec, dealt, player, nil, nil, not isAuto)" in release, "Q passes not isAuto")
    skill = read(SSS / "SkillService.luau")
    check(skill.count("kit.HitMonster(rec, dealt, player, false, ctx.CastId, not ctx.Auto)") == 1
          and skill.count("kit.HitMonster(rec, dealt, player, false, f.Ctx.CastId, not f.Ctx.Auto)") == 1,
          "Z / X and a field's ticks pass not Auto (the cast's own press)")
    check(len(re.findall(r"\bkit\.HitMonster\(", skill)) == 2 and len(re.findall(r"\bdamageMonster\(", combat)) == 3,
          "no other monster damage path (2 skill sites, 2 combat sites + the helper)")
    check(len(re.findall(r"MonsterService\.DamageMonster\(", "".join(read(p) for p in SSS.glob("*.luau")))) == 2,
          "DamageMonster: the definition and CombatService's helper only")
    everything = "".join(read(p) for p in (ROOT / "src").rglob("*.luau")).lower()
    check("shake it down" not in everything, "no 'Shake it down' anywhere in src")
    config = read(SHARED / "Config.luau")
    boost = re.search(r"GoldSources\s*=\s*\{([^}]*)\}", config)
    check(boost is None or "Finisher" not in boost.group(1), "Finisher is not a 2x gold source")
    doc = read(ROOT / "docs/design/king_finisher_2026-10-08.md")
    for word in ("FinisherCard", "FinisherPick", "FinisherEnd", "Deeds", "Finisher"):
        check(word in doc, f"the contract names {word}")
    return count, failures


SUITE = Suite(
    mark="FINISHER",
    fixture=ROOT / "tools/fixtures/finisher_offline.luau",
    world=ROOT / "tools/fixtures/dev2_combat_world.luau",
    out=ROOT / "docs/art/verification_2026-10-08/offline_dev2_finisher_2026-10-08.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="King Slime finisher card (docs/design/king_finisher_2026-10-08.md): the kill is unchanged for everyone; "
             "a paid contributor with an accepted manual hit (swing / Q / Z by hand, not auto) within the "
             "ContributorWindow gets Fx FinisherCard { Id, Kind, Seconds, Stat, Help { Item, N, Score }, Tickle { Gold, "
             "Score } }; c->s FinisherPick(id, Help | Tickle) only for the open card, its Id, within Seconds + Grace, once, "
             "0.3 s rate; Fx FinisherEnd { Id, Pick, Stat, Score, Item, N, Gold }. Help = 2 Jelly (a full bag pays the "
             "rest at sell price), Tickle = 4 bank gold 'Finisher' (not a 2x source). My side +1 inside Deeds "
             "(5 a KST day, the one P9 cap), the other side -1 (A23-58, floor 0, off-side / rank-down lines), Neutral "
             "the gift only; AddStat only (no weekly ranking). One open card at a time; not picked / left = None. "
             "Metric FinisherPick (Halo | Horns | None, faction). Signal Picked(player, pick, kind).",
    limitations="The client card (game dev 1) is not here. Kills run through the real CombatService / SkillService "
                "presses and MonsterService's real DamageMonster + killRecord (cut out) in the combat world; the other "
                "MonsterService parts, the real ProgressionService (its 2x passes) and TelemetryService are doubles. "
                "A field's later ticks (X) pass the cast's own press: checked as source text only.",
)

if __name__ == "__main__":
    run(SUITE)
