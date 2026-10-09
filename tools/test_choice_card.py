"""A23-86 Deeds (the daily deeds ledger) + ChoiceCard (the shared choice card) (게임성 개발 3, 2026-10-09), offline.

Runs the CURRENT Config, Util, Deeds and ChoiceCard on tools/fixtures/dev2_kit.luau + tools/fixtures/dev3_world.luau with
tools/fixtures/choice_card_offline.luau and the installed official Luau CLI: PlayerService / ProgressionService /
LootService are doubles. Test card kinds are injected (Config.ChoiceCard.Kinds ships empty). Static checks: the remote,
the service lists, the debug hook, no purchase prompt, English only. No Studio, network, DataStore or Roblox API calls;
mutations run on in-memory copies of the sources only.

Usage: py tools/test_choice_card.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-09/offline_dev3_choice_card_2026-10-09.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "DEEDS_SOURCE": SSS / "Deeds.luau",
    "CARD_SOURCE": SSS / "ChoiceCard.luau",
}
C, D, K = "CONFIG_SOURCE", "DEEDS_SOURCE", "CARD_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # --- A23-87 (게임성 개발 2): a card's XP reward, never 2x
    ("card XP doubled by the pass", K, "pcall(S.ProgressionService.AddXP, player, xp, xp)",
     "pcall(S.ProgressionService.AddXP, player, xp)"),
    ("card XP never paid", K, "\tif xp > 0 then\n\t\tlocal ok, added = pcall(S.ProgressionService.AddXP", "\tif false then\n\t\tlocal ok, added = pcall(S.ProgressionService.AddXP"),
    ("no XP on the card", K, "Gold = r.Gold, XP = r.XP, Score", "Gold = r.Gold, Score"),
    ("no XP in CardEnd", K, "out.Item, out.N, out.Gold, out.XP = id, given, gold, xp", "out.Item, out.N, out.Gold = id, given, gold"),
    ("no XP in the line", K, "\t\tif xp > 0 then table.insert(parts, string.format(TXT.XP or \"+%s XP\", Util.FormatNumber(xp))) end\n", ""),
    # --- Deeds: the cap
    ("config: 7 points a day", C, "\tPerDay = 6,\n\tPoints = 1,", "\tPerDay = 7,\n\tPoints = 1,"),
    ("config: a deed is 2", C, "\tPerDay = 6,\n\tPoints = 1,", "\tPerDay = 6,\n\tPoints = 2,"),
    ("no cap on the rise", D, "\tlocal give = math.min(n, math.max(0, perDay() - b.N))\n", "\tlocal give = n\n"),
    ("the day is not checked", D, "\tif b.Day ~= day then b.Day, b.N = day, 0 end\n", ""),
    ("the day line uses UTC", D, "\tlocal day = Config.DayIndex(os.time())\n", "\tlocal day = math.floor(os.time() / 86400)\n"),
    ("N above the cap kept", D, "\tb.N = math.clamp(math.floor(num(b.N)), 0, perDay())\n", "\tb.N = math.floor(num(b.N))\n"),
    ("negative N kept", D, "\tb.N = math.clamp(math.floor(num(b.N)), 0, perDay())\n", "\tb.N = math.min(math.floor(num(b.N)), perDay())\n"),
    ("a loss uses the cap", D, "\tlocal have = ownStat(player, stat)\n\tlocal take = math.min(have, n)\n",
     "\tlocal have = ownStat(player, stat)\n\tDeeds.Take(player, n)\n\tlocal take = math.min(have, n)\n"),
    ("a full day blocks the loss", D, "\tlocal have = ownStat(player, stat)\n\tlocal take = math.min(have, n)\n",
     "\tlocal have = ownStat(player, stat)\n\tif Deeds.Left(player) <= 0 then return stat, 0, false, false, false end\n\tlocal take = math.min(have, n)\n"),
    ("the full flag never set", D, "\t\treturn stat, got, true, false, got < n\n", "\t\treturn stat, got, true, false, false\n"),
    ("the attribute is not published", D, "\tplayer:SetAttribute(\"DeedsToday\", b and b.N or 0)\n", ""),
    ("no day check for online players", D, "\t\t\t\t\tlocal ok, err = pcall(publish, p)\n\t\t\t\t\tif not ok then Util.Warn(TAG, \"day: \" .. tostring(err)) end\n", ""),
    ("Take does not book", D, "\tb.N += give\n", ""),
    # --- Deeds: sides and floor
    ("the sides are swapped", D, "\tif (f == \"Halo\") == (side == \"Good\") then\n\t\tlocal got = Deeds.Take(player, n)",
     "\tif (f == \"Halo\") ~= (side == \"Good\") then\n\t\tlocal got = Deeds.Take(player, n)"),
    ("Honor and Infamy swapped", D, "\treturn f == \"Halo\" and \"Honor\" or \"Infamy\"\n", "\treturn f == \"Halo\" and \"Infamy\" or \"Honor\"\n"),
    ("a loss can go below 0", D, "\tlocal take = math.min(have, n)\n", "\tlocal take = n\n"),
    ("the lost rank is never reported", D, "\t\tdown = rankOf(f, have - take) < rankOf(f, have)\n", "\t\tdown = false\n"),
    ("no side still moves a stat", D, "\tlocal f = factionOf(player)\n\tif not f then return \"None\", 0, false, false, false end\n",
     "\tlocal f = factionOf(player) or \"Halo\"\n"),
    ("an unknown side counts as Good", D, "\tif side ~= \"Good\" and side ~= \"Evil\" then return \"None\", 0, false, false, false end\n", ""),
    ("size not clamped", D, "\treturn math.clamp(n, 0, perDay())\n", "\treturn n\n"),
    ("NaN is not repaired", D, "\tn = math.floor(num(n, points()))\n", "\tn = math.floor(n)\n"),
    ("Preview ignores the day", D, "return stat, math.min(n, Deeds.Left(player)), true end", "return stat, n, true end"),
    # --- ChoiceCard: one at a time, saved, committed first
    ("two cards at once", K, "\tif OPEN[player] then return false, \"open\" end\n", ""),
    ("the card is not saved", K, "\t\tc.Pending = { Id = id, Kind = kind, Ctx = card.Ctx }\n", ""),
    ("the saved card is not shown at join", K, "\t\tsend(player, OPEN[player]) -- a saved card waits for the player\n", ""),
    ("a timed card is saved", K, "\tif d.Seconds ~= nil then\n\t\tlocal seconds", "\tif false then\n\t\tlocal seconds"),
    ("a timed card comes back from the save", K, "\t\tif not d or d.Seconds ~= nil then\n", "\t\tif not d then\n"),
    ("an unknown pending kind kept", K, "\t\tif not d or d.Seconds ~= nil then\n", "\t\tif false then\n"),
    ("the serial is not lifted", K, "\t\t\tif p.Id > c.Serial then c.Serial = p.Id end\n", ""),
    ("the serial does not move", K, "\tc.Serial += 1\n", ""),
    ("pending cleared after paying", K, "\t\tif c.Pending and c.Pending.Id == card.Id then c.Pending = nil end -- committed before anything is paid\n", ""),
    ("closing twice pays twice", K, "\tif OPEN[player] ~= card then return end\n", ""),
    # --- ChoiceCard: validation
    ("any argument count", K, "\tif select(\"#\", ...) ~= 2 then return end\n", ""),
    ("any side string", K, "or SIDES[side] ~= true then return end", "then return end"),
    ("the id is not checked", K, "\tif not card or card.Id ~= id then return end\n", "\tif not card then return end\n"),
    ("no rate limit", K, "\tif not Util.RateLimit(player, \"CardAction\", num(Config.RateLimits.CardAction, 0.3)) then return end\n", ""),
    ("no Grace second", K, "\t\ttask.delay(seconds + math.max(0, num(CC.Grace, 1)), function() finish(player, card, nil) end)\n",
     "\t\ttask.delay(seconds, function() finish(player, card, nil) end)\n"),
    ("a timed card never ends", K, "\t\ttask.delay(seconds + math.max(0, num(CC.Grace, 1)), function() finish(player, card, nil) end)\n", ""),
    ("a leaving timed card stays open", K, "\t\tif card and card.Ends then pcall(finish, player, card, nil) end -- a timed card ends; a saved one stays saved\n", ""),
    ("a leaving saved card is deleted", K, "\t\tif card and card.Ends then pcall(finish, player, card, nil) end", "\t\tif card then pcall(finish, player, card, nil) end"),
    # --- ChoiceCard: rewards and points
    ("gold tagged as a quest", K, "pcall(S.ProgressionService.AddBankGold, player, gold, \"Choice\")", "pcall(S.ProgressionService.AddBankGold, player, gold, \"Quest\")"),
    ("the bag overflow is lost", K, "\t\tgold += (want - given) * math.max(0, math.floor(num(item and item.Sell)))\n", ""),
    ("points skip the ledger", K, "S.Deeds.Add(player, side, o.Points)", "S.PlayerService.AddStat(player, \"Honor\", 1), 0, true, false, false"),
    ("the pick is not counted", K, "\t\tcount(data, card.Kind, side)\n", ""),
    ("the count resets", K, "\tst.N[kind][side] = math.min(1000000, math.max(0, math.floor(num(st.N[kind][side]))) + 1)\n", "\tst.N[kind][side] = 1\n"),
    ("a time up pays", K, "\tif side and d and data then\n", "\tif d and data then\n\t\tside = side or \"Good\"\n"),
    ("the Evil option pays the Good reward", K, "\t\tlocal given, gold, id, xp = pay(player, o.Reward)\n", "\t\tlocal given, gold, id, xp = pay(player, d.Good.Reward)\n"),
    ("the full-day line is missing", K, "\t\telseif mine and full then\n\t\t\tnotify(player, TXT.Full, \"info\")\n", "\t\telseif false then\n"),
    ("no off-side line", K, "\t\tif stat ~= \"None\" and not mine then\n", "\t\tif false then\n"),
    ("no rank line", K, "\t\t\tif down then notify(player, f == \"Halo\" and STORY.RankDownHalo or STORY.RankDownHorns, \"info\") end\n", ""),
    ("the end is not sent", K, "\tif player.Parent == Players then fx(player, \"CardEnd\", out) end\n", ""),
    ("the signal never fires", K, "\tChoiceCard.Picked:Fire(player, card.Kind, out.Side, out)\n", ""),
    ("the card shows no preview score", K, "local stat, score, mine = S.Deeds.Preview(player, side, o.Points)", "local stat, score, mine = S.Deeds.Preview(player, side, o.Points) score = 0"),
    ("no Neutral hint", K, "if stat == \"None\" then hint = \"Neutral\" elseif", "if false then hint = \"Neutral\" elseif"),
    ("a not-ready player gets a card", K, "\tif not data or not S.PlayerService.IsReady(player) then return false, \"notready\" end\n", ""),
    ("any kind", K, "\tif not d then return false, \"kind\" end\n", ""),
    # --- config
    ("config: the cap line is different", C, "Your shard is full for today. Come back tomorrow!", "You are done."),
    ("config: no card rate limit", C, "Config.RateLimits.CardAction = 0.3\n", ""),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    net = read(SHARED / "Net.luau")
    check(net.count('"CardAction"') == 1, "Net.Names has CardAction once")
    main = read(SSS / "Main.server.luau")
    init = re.search(r"local INIT_ORDER = \{(.*?)\n\}", main, re.S)
    start = re.search(r"local START_ORDER = \{(.*?)\n\}", main, re.S)
    names = re.compile(r'"(\w+)"')
    init_list = names.findall(init.group(1)) if init else []
    start_list = names.findall(start.group(1)) if start else []
    for name in ("Deeds", "ChoiceCard"):
        check(init_list.count(name) == 1, f"INIT_ORDER lists {name} once")
        check(start_list.count(name) == 1 and start_list.index(name) < start_list.index("PlayerService") and start_list[-1] == "PlayerService",
              f"START_ORDER starts {name} before PlayerService (PlayerService stays last)")
        check((SSS / f"{name}.luau").is_file(), f"{name}.luau exists (a listed module without a file hangs the server)")
    check(init_list.index("Deeds") < init_list.index("ChoiceCard"), "Deeds is initialised before ChoiceCard")
    check(sorted(init_list) == sorted(start_list), "every service is in both lists")
    check('elseif key == "Card" then' in main and "S.ChoiceCard.Offer(player" in main, "Studio DebugCommand Card")
    card = read(SSS / "ChoiceCard.luau")
    deeds = read(SSS / "Deeds.luau")
    check('Net.Get("CardAction").OnServerEvent:Connect' in card, "ChoiceCard listens to CardAction")
    for label, text in (("ChoiceCard", card), ("Deeds", deeds)):
        code = "\n".join(l.split("--", 1)[0] for l in text.splitlines())
        check(not re.search(r"[가-힣]", code), f"{label}: no Korean outside comments (game text is English only, A23-48)")
        check("MarketplaceService" not in code and "Prompt" not in code, f"{label}: nothing sold, no purchase prompt (A23-79)")
    check("AddStat" not in "\n".join(l.split("--", 1)[0] for l in card.splitlines()), "ChoiceCard has no AddStat / SetStat of its own")
    check("math.random" not in card and "Random" not in card, "no draw: the reward is fixed")
    config = read(SHARED / "Config.luau")
    block = config[config.find("-- A23-86 Deeds + shared choice card"):]
    code = "\n".join(l.split("--", 1)[0] for l in block.splitlines())
    check(not re.search(r"[가-힣]", code), "Config Deeds / ChoiceCard block: English text only")
    return count, failures


SUITE = Suite(
    mark="CHOICECARD",
    fixture=ROOT / "tools/fixtures/choice_card_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-09/offline_dev3_choice_card_2026-10-09.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-86: Deeds = one cap a KST day (6 points) for every repeated Honor / Infamy change, +1 own side / -1 "
             "other side with a 0 floor, a lost rank reported, a full day keeps the reward, DeedsToday / DeedsMax "
             "attributes, back to 0 at 00:00 KST, repaired save data.Deeds { Day, N }; ChoiceCard = a card only the "
             "player sees (Config.ChoiceCard.Kinds), Good and Evil of the same size with a FIXED reward, one open card a "
             "player, saved cards wait with no limit and come back at the next join (data.Cards { Serial, Pending }), "
             "timed cards are not saved (time up = None), c->s CardAction(id, side) validated and rate limited, gold "
             "source 'Choice', overflow items paid at the sell price, points only through Deeds.Add, every pick counted "
             "in data.Story.N[kind][side], Fx Card / CardEnd, signal Picked.",
    limitations="The card screen is client work (game dev 1). The real card kinds (lost items, apprentice, clatter) and the "
                "Finisher migration come with their content; the test kinds are injected. My Way does not read Story.N yet "
                "(the weight is decided: 5 repeated picks = 1 story pick, capped).",
)

if __name__ == "__main__":
    run(SUITE)
