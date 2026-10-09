"""A23-86 decision 2 - Otto's commissions (CommissionService, content_beyond_10min H) (게임성 개발 3, 2026-10-09), offline.

At the Forge the golden / crystal / spirit weapons (T4-T6) can be ordered with gold + materials + the weapon's level; the
server checks everything first and takes it all in one go, the weapon is owned and equipped, and the apprentice card
(ChoiceCard, saved) opens a moment later. Also the next-goal ladder line. Runs the CURRENT Config, Util, Deeds, ChoiceCard and
CommissionService on tools/fixtures/dev2_kit.luau + tools/fixtures/dev3_world.luau with tools/fixtures/commission_offline.luau
and the installed official Luau CLI (ShopService.CanBuyWeapon, ClassService.GetClass, ProgressionService.SpendGold are
doubles). No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies only.

Usage: py tools/test_commission.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-09/offline_dev3_commission_2026-10-09.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "DEEDS_SOURCE": SSS / "Deeds.luau",
    "CARD_SOURCE": SSS / "ChoiceCard.luau",
    "COMM_SOURCE": SSS / "CommissionService.luau",
}
C, D, K, M = "CONFIG_SOURCE", "DEEDS_SOURCE", "CARD_SOURCE", "COMM_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # --- config
    ("config: the switch is on", C, "Config.Features.Commission = false", "Config.Features.Commission = true"),
    ("config: T4 costs 2,000", C, "[4] = { Gold = 3000,", "[4] = { Gold = 2000,"),
    ("config: T4 needs 5 horns", C, "Items = { BruteHorn = 10, GoblinTooth = 20 }", "Items = { BruteHorn = 5, GoblinTooth = 20 }"),
    ("config: T5 asks for jelly", C, "Items = { KnightCrest = 12, Bone = 30 }", "Items = { Jelly = 12, Bone = 30 }"),
    ("config: no commission in the T4 source", C, "Rare drop from Goblins and Goblin Brutes, or a Forge commission", "Rare drop from Goblins and Goblin Brutes"),
    ("config: the card scroll is 2", C, 'Reward = { Item = "Enh70", N = 1 }, Points = 1, Done = "Otto\'s apprentice beams." }', 'Reward = { Item = "Enh70", N = 2 }, Points = 1, Done = "Otto\'s apprentice beams." }'),
    ("config: the discount is 5 minutes", C, "Reward = { GoldMin = 2 }", "Reward = { GoldMin = 5 }"),
    ("config: the card is timed", C, 'Title = "The apprentice scratched the hilt a little.",', 'Title = "The apprentice scratched the hilt a little.", Seconds = 10,'),
    ("config: no rate limit entry", C, "Config.RateLimits.Commission = 1\n", ""),
    ("config: the card scores 2", C, 'Evil = { Label = "Fix it AND give me a discount!", Reward = { GoldMin = 2 }, Points = 1,', 'Evil = { Label = "Fix it AND give me a discount!", Reward = { GoldMin = 2 }, Points = 2,'),
    ("config: no card kind", C, "	Card = \"ApprenticeScratch\",\n", "	Card = \"Nothing\",\n"),
    # --- the order
    ("the switch is ignored", M, '	if not Config.FeatureOn("Commission") then return end\n	local order = orderOf(tier)', '	local order = orderOf(tier)'),
    ("any argument count", M, '	if select("#", ...) ~= 1 then return end\n', ""),
    ("not ready players order", M, "	if not S.PlayerService.IsReady(player) then return end\n	if not Util.RateLimit(player, \"Commission\"", "	if not Util.RateLimit(player, \"Commission\""),
    ("no rate limit", M, '	if not Util.RateLimit(player, "Commission", num(Config.RateLimits.Commission, 1)) then return end\n', ""),
    ("anywhere in the world", M, "	if not S.ShopService.CanBuyWeapon(player) then\n		notify(player, Config.Text.WeaponShopFar, \"bad\")\n		return\n	end\n", ""),
    ("an owned weapon is paid again", M, "	if owned(data, tier) then\n		notify(player, TXT.Owned, \"info\")\n		return\n	end\n", ""),
    ("no level check", M, "	if num(data.Level, 1) < num(def.MinLevel, 1) then\n", "	if false then\n"),
    ("level one lower", M, "if num(data.Level, 1) < num(def.MinLevel, 1) then", "if num(data.Level, 1) < num(def.MinLevel, 1) - 1 then"),
    ("in combat", M, "	if S.CombatService.IsInCombat(player) then\n		notify(player, Config.Loot.Text.EquipCombat, \"bad\")\n		return\n	end\n", ""),
    ("materials not checked", M, "		if have(data, m.Id) < m.N then\n", "		if false then\n"),
    ("one material short is enough", M, "		if have(data, m.Id) < m.N then\n", "		if have(data, m.Id) < m.N - 1 then\n"),
    ("gold not spent", M, "	if not S.ProgressionService.SpendGold(player, price, \"Commission\") then\n		notify(player, Config.Text.NotEnoughGold, \"bad\")\n		return\n	end\n", ""),
    ("the spend is tagged as a sale", M, "SpendGold(player, price, \"Commission\")", "SpendGold(player, price, \"Weapon\")"),
    ("materials not taken", M, "		if not S.LootService.TakeItem(player, m.Id, m.N) then\n", "		if false then\n"),
    ("only one material taken", M, "	for _, m in list do\n		if not S.LootService.TakeItem", "	for _, m in { list[1] } do\n		if not S.LootService.TakeItem"),
    ("the weapon is not owned", M, "	S.PlayerService.SetStat(player, \"WeaponOwnedMask\", bit32.bor(mask, bit32.lshift(1, tier - 1)))\n", ""),
    ("the wrong bit", M, "bit32.bor(mask, bit32.lshift(1, tier - 1))", "bit32.bor(mask, bit32.lshift(1, tier))"),
    ("not equipped", M, "	S.PlayerService.SetStat(player, \"WeaponTier\", tier)\n", ""),
    ("no Forge visit", M, "	S.PlayerService.SetStat(player, \"BlacksmithVisited\", true)\n", ""),
    ("no equip line", M, "	notify(player, string.format(TXT.Done, name), \"reward\", \"Equip\")\n", ""),
    ("no Upgrade fx", M, "	pcall(Net.Fx, player, \"Upgrade\", { Tier = tier })\n", ""),
    ("no Commission fx", M, "	pcall(Net.Fx, player, \"Commission\", { Tier = tier, Name = name })\n", ""),
    ("no Made signal", M, "	CommissionService.Made:Fire(player, tier)\n", ""),
    ("no card", M, "	if type(card) == \"string\" and S.ChoiceCard then\n", "	if false then\n"),
    ("the card at once", M, "task.delay(num(K.CardDelay, 1.5), function()", "task.delay(0, function()"),
    # --- the card's gold
    ("the card gold ignores the level", K, "out.Gold = math.max(0, math.floor(num(r.Gold))) + select(1, Config.HuntValue(level, num(r.GoldMin)))", "out.Gold = math.max(0, math.floor(num(r.Gold))) + select(1, Config.HuntValue(1, num(r.GoldMin)))"),
    ("the card pays xp-minutes as gold", K, "select(1, Config.HuntValue(level, num(r.GoldMin)))", "select(2, Config.HuntValue(level, num(r.GoldMin)))"),
    ("the preview forgets GoldMin", K, "	local r = concrete(player, o.Reward)\n", "	local r = type(o.Reward) == \"table\" and o.Reward or {}\n"),
    ("the pick forgets GoldMin", K, "pay(player, concrete(player, o.Reward))", "pay(player, o.Reward)"),
    # --- the next-goal line
    ("next goal ignores the switch", M, "	if not Config.FeatureOn(\"Commission\") or type(data) ~= \"table\" then return nil end\n", "	if type(data) ~= \"table\" then return nil end\n"),
    ("next goal names owned weapons", M, "		if order and not owned(data, tier) then\n", "		if order then\n"),
    ("next goal ignores ShowLevel", M, "			if level < num(order.ShowLevel, num(Config.Weapons[tier].MinLevel, 1)) then return nil end\n", ""),
    ("next goal names the first material", M, "if frac < 1 and frac < worstFrac then worst, worstFrac = m, frac end", "if frac < 1 and not worst then worst, worstFrac = m, frac end"),
    ("next goal never says ready", M, "			return string.format(TXT.GoalReady, label), \"Commission\" .. tier\n", "			return nil\n"),
    ("next goal has no kind", M, '"Commission" .. tier\n			end\n			return string.format(TXT.GoalReady', '"Commission"\n			end\n			return string.format(TXT.GoalReady'),
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
    check(net.count('"Commission"') == 1, "Net.Names has Commission once")
    main = read(SSS / "Main.server.luau")
    init = re.search(r"local INIT_ORDER = \{(.*?)\n\}", main, re.S)
    start = re.search(r"local START_ORDER = \{(.*?)\n\}", main, re.S)
    names = re.compile(r'"(\w+)"')
    init_list = names.findall(init.group(1)) if init else []
    start_list = names.findall(start.group(1)) if start else []
    check(init_list.count("CommissionService") == 1 and start_list.count("CommissionService") == 1, "CommissionService is in both lists once")
    check(start_list.index("CommissionService") < start_list.index("PlayerService") and start_list[-1] == "PlayerService",
          "CommissionService starts before PlayerService (PlayerService stays last)")
    check((SSS / "CommissionService.luau").is_file(), "the service file exists (a listed module without a file hangs the server)")
    check(sorted(init_list) == sorted(start_list), "every service is in both lists")
    comm = read(SSS / "CommissionService.luau")
    code = "\n".join(l.split("--", 1)[0] for l in comm.splitlines())
    check('Net.Get("Commission").OnServerEvent:Connect' in code, "the service listens to Commission")
    check(not re.search(r"[가-힣]", code), "no Korean outside comments (game text is English only, A23-48)")
    check("MarketplaceService" not in code and "Prompt" not in code and "Robux" not in code, "nothing sold, no purchase prompt (A23-79)")
    check("math.random" not in code, "no draw: the order is fixed")
    config = read(SHARED / "Config.luau")
    block = config[config.find("-- A23-86 decision 2 = A (user 2026-10-09)"):]
    block = block[: block.find("\n}\n", block.find("Config.ChoiceCard.Kinds.ApprenticeScratch")) + 3]
    cc = "\n".join(l.split("--", 1)[0] for l in block.splitlines())
    check(not re.search(r"[가-힣]", cc), "Config commission block: English text only")
    check('"Commission"' in config and "Ladder" in config, "the ladder knows the Commission hook")
    return count, failures


SUITE = Suite(
    mark="COMMISSION",
    fixture=ROOT / "tools/fixtures/commission_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-09/offline_dev3_commission_2026-10-09.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-86 decision 2 = A: c->s Commission(tier) (T4-T6, one integer, 1 s, switched by Config.Features.Commission, "
             "off for now): at the Forge, ready, alive, not in combat, the weapon not owned, Level >= its MinLevel, every material, "
             "the gold; all checked first then taken in one go (gold through SpendGold 'Commission' carried first, materials "
             "through TakeItem), the weapon owned + equipped (WeaponOwnedMask bit, WeaponTier, BlacksmithVisited), line + Fx "
             "Upgrade + Fx Commission, signal Made, then the saved apprentice card (ChoiceCard 'ApprenticeScratch': a 70% scroll "
             "or 2 minutes of hunting gold, 1 point each way); orders T4 3,000 + 10 Brute Horn + 20 Goblin Tooth, T5 10,000 + 12 "
             "Knight Crest + 30 Bone, T6 30,000 + 30 Knight Crest + 60 Bone (T5 / T6 proposed); the shop still sells up to T3; "
             "NextGoal(player, data) for the ladder ('Next goal · Golden weapon: Brute Horn 6/10 · 2,140/3,000 gold').",
    limitations="The Forge window's [Commission] row and the 'power A -> B' show are game dev 1's (the switch stays off until "
                "the row exists). T5 / T6 materials and the T4 card numbers are proposals for 검수's decision 2-2.",
)

if __name__ == "__main__":
    run(SUITE)
