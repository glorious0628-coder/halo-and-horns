"""#45 Lost & Found (LostFoundService) (게임성 개발 3, 2026-10-10), offline.

content_beyond_10min C / zone_check_halo #45 (contract docs/design/lost_found_server_2026-10-10.md): a monster in a zone with an
item sometimes drops what somebody lost (a per-player kill beat: nothing below 60 kills, rising evenly to sure at 100, then it
starts again; one thing held at a time; 3 finds a KST day); a find opens the item's ChoiceCard (Good = give it back, Evil = the
finder's fee, or a trophy for what is not a child's); the card pays nothing, the pick sends the player to the Lost & Found bench
(Crossroads) or to the own town (the vault); arriving pays 2 minutes of hunting (Good: XP + potions + the day's first scroll,
Evil: gold; source Choice, never 2x). Runs the CURRENT Config, Util, Deeds, ChoiceCard and LostFoundService on
tools/fixtures/dev2_kit.luau + tools/fixtures/dev3_world.luau with tools/fixtures/lost_found_offline.luau and the installed
official Luau CLI (PlayerService / ProgressionService / LootService / ZoneService / MonsterService are the dev3_world doubles,
QuestService a MarkDirty counter). Static checks: both service lists, the DebugCommand, the quest-list hook, English only, no
purchase prompt. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_lost_found.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-10/offline_dev3_lost_found_2026-10-10.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "DEEDS_SOURCE": SSS / "Deeds.luau",
    "CARD_SOURCE": SSS / "ChoiceCard.luau",
    "LF_SOURCE": SSS / "LostFoundService.luau",
}
C, LF = "CONFIG_SOURCE", "LF_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    ("bag 10/14: a reward refused when the bag is full", "LF_SOURCE", "pcall(S.LootService.GrantItem, player, id, want, \"Reward\")", "pcall(S.LootService.GrantItem, player, id, want)"),
    # --- config
    ("config: on by default", C, "Config.LostFound = {\n\tEnabled = false,", "Config.LostFound = {\n\tEnabled = true,"),
    ("config: the chance starts at 50 kills", C, "\tFrom = 60, -- kills before", "\tFrom = 50, -- kills before"),
    ("config: sure at 99 kills", C, "\tSure = 100, -- the kill", "\tSure = 99, -- the kill"),
    ("config: four a day", C, "\tDayCap = 3,\n\tRewardMinutes", "\tDayCap = 4,\n\tRewardMinutes"),
    ("config: 3 minutes of hunting", C, "\tRewardMinutes = 2,\n\tBench", "\tRewardMinutes = 3,\n\tBench"),
    ("config: the bench range is 20", C, "Range = 10 },\n\tOrder", "Range = 20 },\n\tOrder"),
    ("config: the bench is in the meadow", C, "Bench = { Zone = \"Crossroads\",", "Bench = { Zone = \"SlimeMeadow\","),
    ("config: the teddy drops in the woods", C, "Teddy = { Name = \"Lost Teddy\", Zone = \"SlimeMeadow\"", "Teddy = { Name = \"Lost Teddy\", Zone = \"GoblinWoods\""),
    ("config: the badge belongs to a child", C, "Owner = \"Goblin\", Card = \"LostBadge\"", "Owner = \"Kid\", Card = \"LostBadge\""),
    ("config: the teddy is not a child's", C, "Teddy = { Name = \"Lost Teddy\", Zone = \"SlimeMeadow\", Owner = \"Kid\"", "Teddy = { Name = \"Lost Teddy\", Zone = \"SlimeMeadow\", Owner = \"Guard\""),
    ("config: the candy bag has no season", C, ", Card = \"LostCandy\", Season = \"Halloween\" }", ", Card = \"LostCandy\" }"),
    ("config: no save default", C, "Config.Data.Defaults.LostFound = { Day = 0, N = 0, K = 0 }\n", ""),
    ("config: a timed teddy card", C, "Config.ChoiceCard.Kinds.LostTeddy = {\n\tTitle =", "Config.ChoiceCard.Kinds.LostTeddy = {\n\tSeconds = 20, Title ="),
    ("config: the teddy card pays itself", C, "Evil = { Label = \"Finder's fee!\", Points = 1, Done = \"Sneaky! Ask for a fee at the Lost & Found.\" },\n}\nConfig.ChoiceCard.Kinds.LostCandy",
     "Evil = { Label = \"Finder's fee!\", Points = 1, Reward = { Gold = 5 }, Done = \"Sneaky! Ask for a fee at the Lost & Found.\" },\n}\nConfig.ChoiceCard.Kinds.LostCandy"),
    ("config: the badge card asks a fee", C, "Evil = { Label = \"Keep it as a trophy\", Points = 1, Done = \"A fine trophy! Stash it in your vault.\" },\n}\nConfig.ChoiceCard.Kinds.LostMedal",
     "Evil = { Label = \"Finder's fee!\", Points = 1, Done = \"A fine trophy! Stash it in your vault.\" },\n}\nConfig.ChoiceCard.Kinds.LostMedal"),
    ("config: a long short name", C, "ShortBench = \"Lost & Found\",", "ShortBench = \"The Lost & Found Bench\","),
    # --- the beat
    ("beat: nothing is ever sure", LF, "\tif kills >= sure then return 1 end\n", ""),
    ("beat: the chance never rises", LF, "\treturn (kills - from + 1) / (sure - from + 1)\n", "\treturn 0.5\n"),
    ("beat: the chance rises from 0", LF, "\treturn (kills - from + 1) / (sure - from + 1)\n", "\treturn (kills - from) / (sure - from + 1)\n"),
    ("beat: any roll finds", LF, "if chance > 0 and Util.Random:NextNumber() < chance then", "if chance > 0 then"),
    ("beat: a kill is not counted", LF, "\tst.K = math.min(1000000, st.K + 1)\n", "\tst.K = math.min(1000000, st.K)\n"),
    ("beat: the count survives a find", LF, "\tst.N += 1\n\tst.K = 0\n", "\tst.N += 1\n"),
    ("beat: no daily cap", LF, "\tif st.N >= math.max(0, math.floor(num(cfg().DayCap, 3))) then return end\n", ""),
    ("beat: a free rider counts", LF, "if type(info) ~= \"table\" or info.Minor == true then return end", "if type(info) ~= \"table\" then return end"),
    ("beat: a player who is not ready counts", LF,
     "\tif not okReady or not ready then return end\n\tlocal data = dataOf(player)\n\tif not data then return end\n\tlocal st = state(data)\n\tif st.Holding then",
     "\tlocal data = dataOf(player)\n\tif not data then return end\n\tlocal st = state(data)\n\tif st.Holding then"),
    ("beat: off still counts", LF, "\treturn cfg().Enabled == true\n", "\treturn true\n"),
    ("beat: holding one keeps counting", LF, "if st.Holding.Phase == \"Choose\" then offer(player, st) end\n\t\treturn\n", "if st.Holding.Phase == \"Choose\" then offer(player, st) end\n"),
    ("beat: a held find is never offered again", LF, "if st.Holding.Phase == \"Choose\" then offer(player, st) end\n\t\treturn\n", "\t\treturn\n"),
    ("beat: a zone with no item counts", LF, "\tlocal id = itemForZone(info.ZoneId)\n\tif not id then return end\n", "\tlocal id = itemForZone(info.ZoneId) or \"Teddy\"\n"),
    ("beat: any zone has the item", LF, "if d and d.Zone == zoneId and Config.SeasonOn(d.Season) then return id, d end", "if d and Config.SeasonOn(d.Season) then return id, d end"),
    ("beat: out of season", LF, "if d and d.Zone == zoneId and Config.SeasonOn(d.Season) then return id, d end", "if d and d.Zone == zoneId then return id, d end"),
    # --- the find
    ("find: not the day's first", LF, "First = st.N == 1 }", "First = true }"),
    ("find: no card", LF, "\tLostFoundService.Found:Fire(player, id, zoneId)\n\toffer(player, st)\n", "\tLostFoundService.Found:Fire(player, id, zoneId)\n"),
    ("find: nobody is told", LF, "\tLostFoundService.Found:Fire(player, id, zoneId)\n", ""),
    ("find: the card knows no item", LF, "pcall(S.ChoiceCard.Offer, player, d.Card, { Item = h.Id })", "pcall(S.ChoiceCard.Offer, player, d.Card, {})"),
    # --- the pick
    ("pick: any answer starts the walk", LF, "if not id or (side ~= \"Good\" and side ~= \"Evil\") then return end", "if not id then return end"),
    ("pick: another card's answer starts it", LF, "if not h or h.Id ~= id or h.Phase ~= \"Choose\" then return end", "if not h or h.Phase ~= \"Choose\" then return end"),
    ("pick: the walk never starts", LF, "h.Phase, h.Side = \"Carry\", side", "h.Phase, h.Side = \"Choose\", side"),
    ("pick: the child's fee goes to the vault", LF, "h.Leg = (side == \"Evil\" and d.Owner ~= \"Kid\") and \"Vault\" or \"Bench\"", "h.Leg = side == \"Evil\" and \"Vault\" or \"Bench\""),
    ("pick: the trophy goes to the bench", LF, "h.Leg = (side == \"Evil\" and d.Owner ~= \"Kid\") and \"Vault\" or \"Bench\"", "h.Leg = \"Bench\""),
    ("pick: no loop for the walker", LF, "\tCARRY[player] = true\n\tdirty(player)\nend", "\tdirty(player)\nend"),
    ("pick: the quest list is not refreshed", LF, "\tCARRY[player] = true\n\tdirty(player)\nend", "\tCARRY[player] = true\nend"),
    # --- the walk
    ("walk: any town is the vault", LF, "if leg == \"Vault\" then return zoneId == Config.HomeZoneId(factionOf(player)) end",
     "if leg == \"Vault\" then return Config.Zones[zoneId] ~= nil and Config.Zones[zoneId].Town == true end"),
    ("walk: the vault is anywhere", LF, "if leg == \"Vault\" then return zoneId == Config.HomeZoneId(factionOf(player)) end", "if leg == \"Vault\" then return true end"),
    ("walk: the bench is in any zone", LF, "\tif zoneId ~= (B.Zone or \"Crossroads\") then return false end\n", ""),
    ("walk: the bench range is exclusive", LF, "<= num(B.Range, 10)", "< num(B.Range, 10)"),
    ("walk: the whole zone is the bench", LF, "return root ~= nil and Util.FlatDistance(root.Position, spot) <= num(B.Range, 10)", "return root ~= nil"),
    ("walk: not ready for the leg", LF, "\tif not legReady(player, h.Leg) then return false end\n", ""),
    ("walk: off still pays", LF, "if not on() or typeof(player) ~= \"Instance\" or not player:IsA(\"Player\") or player.Parent ~= Players then return false end",
     "if typeof(player) ~= \"Instance\" or not player:IsA(\"Player\") or player.Parent ~= Players then return false end"),
    ("walk: the record stays after the payment", LF, "\tst.Holding = nil\n\tCARRY[player] = nil\n\tlocal parts, paid", "\tCARRY[player] = nil\n\tlocal parts, paid"),
    ("walk: no refresh after the payment", LF, "\tdirty(player)\n\tLostFoundService.Delivered:Fire", "\tLostFoundService.Delivered:Fire"),
    ("walk: nobody is told", LF, "\tLostFoundService.Delivered:Fire(player, h.Id, h.Side, h.Leg, paid)\n", ""),
    # A23-130: the turn-in line is the reward parts only; the thank-you lead back must fail
    ("walk: the thank-you lead back", LF, "\tnotify(player, table.concat(parts, \" · \"), \"reward\")\n",
     "\ttable.insert(parts, 1, string.format((cfg().Text or {}).GoodDone or \"%s\", d and d.Name or h.Id))\n"
     "\tnotify(player, table.concat(parts, \" · \"), \"reward\")\n"),
    ("walk: the loop never pays", LF, "\t\t\t\t\tlocal ok, err = pcall(LostFoundService.Deliver, player)\n", "\t\t\t\t\tlocal ok, err = true, nil\n"),
    ("walk: the join forgets the walk", LF, "\t\t\tif st.Holding and st.Holding.Phase == \"Carry\" then CARRY[player] = true end\n", ""),
    # --- the payment
    ("pay: 1 minute of hunting", LF, "Config.HuntValue(level, num(C.RewardMinutes, 2))", "Config.HuntValue(level, 1)"),
    ("pay: level 1 hunting", LF, "\tlocal level = math.max(1, math.floor(num(data.Level, 1)))\n\tlocal gold, xp = Config.HuntValue", "\tlocal level = 1\n\tlocal gold, xp = Config.HuntValue"),
    ("pay: a good turn-in pays no XP", LF, "\t\tout.XP = xp\n", ""),
    ("pay: the fee pays XP too", LF, "\t\tout.Gold = gold\n\tend\n\treturn out", "\t\tout.Gold = gold\n\t\tout.XP = xp\n\tend\n\treturn out"),
    ("pay: a good turn-in pays gold too", LF, "\t\tout.XP = xp\n", "\t\tout.XP = xp\n\t\tout.Gold = gold\n"),
    ("pay: no potions", LF, "for id, n in g.Give or {} do out.Bag[id]", "for id, n in {} do out.Bag[id]"),
    ("pay: no scroll", LF, "\t\tif h.First and type(g.FirstScroll) == \"string\" then out.Bag[g.FirstScroll] = (out.Bag[g.FirstScroll] or 0) + 1 end\n", ""),
    ("pay: a scroll every time", LF, "if h.First and type(g.FirstScroll) == \"string\"", "if type(g.FirstScroll) == \"string\""),
    ("pay: gold from the wrong source", LF, "AddBankGold, player, gold, \"Choice\")", "AddBankGold, player, gold, \"Monster\")"),
    ("pay: XP doubled by the pass", LF, "AddXP, player, xp, xp)", "AddXP, player, xp)"),
    ("pay: a full bag pays nothing", LF, "\t\t\tgold += (want - given) * math.max(0, math.floor(num(item and item.Sell)))\n", ""),
    ("pay: a failing item grant stops everything", LF, "\t\t\tlocal ok, res = pcall(S.LootService.GrantItem, player, id, want)", "\t\t\tlocal ok, res = true, S.LootService.GrantItem(player, id, want)"),
    ("pay: a failing gold payment stops everything", LF, "local ok, added = pcall(S.ProgressionService.AddBankGold, player, gold, \"Choice\")", "local ok, added = true, S.ProgressionService.AddBankGold(player, gold, \"Choice\")"),
    # --- the row
    ("row: shown while off", LF, "\tif not on() or type(data) ~= \"table\" then return {} end\n", "\tif type(data) ~= \"table\" then return {} end\n"),
    ("row: shown before the pick", LF, "local d = h and h.Phase == \"Carry\" and itemDef(h.Id) or nil", "local d = h and itemDef(h.Id) or nil"),
    ("row: the wrong kind", LF, "Id = \"find:\" .. h.Id, Kind = \"Find\"", "Id = \"find:\" .. h.Id, Kind = \"Sub\""),
    ("row: the guides are swapped", LF, "Guide = bench and \"Fountain\" or \"OwnTown\"", "Guide = bench and \"OwnTown\" or \"Fountain\""),
    ("row: the bench text for the vault", LF, "Text = string.format(bench and (T.RowBench or \"%s\") or (T.RowVault or \"%s\"), d.Name)", "Text = string.format(T.RowBench or \"%s\", d.Name)"),
    ("row: no gold shown", LF, "RewardGold = reward.Gold, RewardXP = reward.XP", "RewardGold = 0, RewardXP = reward.XP"),
    # --- the save
    ("save: a new day keeps the finds", LF, "if num(st.Day, -1) ~= today then st.Day, st.N = today, 0 end", "if num(st.Day, -1) ~= today then st.Day = today end"),
    ("save: a walk with no side is kept", LF, "\t\t\tgood = (h.Side == \"Good\" or h.Side == \"Evil\") and (h.Leg == \"Bench\" or h.Leg == \"Vault\")\n", "\t\t\tgood = true\n"),
    ("save: a broken holding is kept", LF, "\t\telse\n\t\t\tst.Holding = nil\n\t\tend", "\t\tend"),
    ("save: any phase is kept", LF, "(h.Phase == \"Choose\" or h.Phase == \"Carry\")", "true"),
    ("save: an unknown item is kept", LF, "itemDef(h.Id) ~= nil and (h.Phase", "(h.Phase"),
    ("save: the finds today are not capped", LF, "st.N = math.clamp(math.floor(num(st.N)), 0, 1000)", "st.N = num(st.N)"),
    ("save: the count is not capped", LF, "st.K = math.clamp(math.floor(num(st.K)), 0, 1000000)", "st.K = num(st.K)"),
    ("save: First is not a boolean", LF, "\t\t\th.First = h.First == true\n", ""),
    # --- hooks
    ("hook: no kill signal", LF, "\tS.MonsterService.MonsterKilled:Connect(function(player, info)\n\t\tlocal ok, err = pcall(LostFoundService.OnKilled, player, info)\n\t\tif not ok then Util.Warn(TAG, \"kill: \" .. tostring(err)) end\n\tend)\n", ""),
    ("hook: no pick signal", LF, "\tS.ChoiceCard.Picked:Connect(function(player, kind, side)\n\t\tlocal ok, err = pcall(onPicked, player, kind, side)\n\t\tif not ok then Util.Warn(TAG, \"picked: \" .. tostring(err)) end\n\tend)\n", ""),
    # --- test aids
    ("debug: a second find while holding", LF, "\tif st.Holding then return \"already holding \" .. tostring(st.Holding.Id) end\n", ""),
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
    init = re.search(r"local INIT_ORDER = \{(.*?)\n\}", main, re.S)
    start = re.search(r"local START_ORDER = \{(.*?)\n\}", main, re.S)
    names = re.compile(r'"(\w+)"')
    init_list = names.findall(init.group(1)) if init else []
    start_list = names.findall(start.group(1)) if start else []
    name = "LostFoundService"
    check(init_list.count(name) == 1, "INIT_ORDER lists LostFoundService once")
    check(start_list.count(name) == 1 and start_list.index(name) < start_list.index("PlayerService") and start_list[-1] == "PlayerService",
          "START_ORDER starts LostFoundService before PlayerService (PlayerService stays last)")
    check(init_list.index("ChoiceCard") < init_list.index(name) and start_list.index("ChoiceCard") < start_list.index(name),
          "LostFoundService comes after ChoiceCard (it listens to ChoiceCard.Picked)")
    check(sorted(init_list) == sorted(start_list), "every service is in both lists")
    check((SSS / f"{name}.luau").is_file(), "LostFoundService.luau exists (a listed module without a file hangs the server)")
    check('elseif key == "Lost" then' in main and "S.LostFoundService.Debug" in main, "Studio DebugCommand Lost")
    check("READ_ONLY" in main and not re.search(r"READ_ONLY = \{[^}]*Lost", main), "the Lost debug key taints the save (it is not read-only)")
    quest = read(SSS / "QuestService.luau")
    jobs = quest.find("board.JobRows")
    lost = quest.find("S.LostFoundService")
    goal = quest.find("local hasGoal")
    check(0 < jobs < lost < goal and "lost.Rows" in quest and "pcall(lost.Rows" in quest,
          "QuestService.publish adds LostFoundService.Rows after the board's jobs, before the guide line")
    code = "\n".join(l.split("--", 1)[0] for l in read(SSS / "LostFoundService.luau").splitlines())
    check(not re.search(r"[가-힣]", code), "LostFoundService: no Korean outside comments (game text is English only, A23-48)")
    check("MarketplaceService" not in code and "Prompt" not in code, "LostFoundService: nothing sold, no purchase prompt (A23-79)")
    check("AddStat" not in code and "SetStat" not in code and "Honor" not in code and "Infamy" not in code,
          "LostFoundService writes no stat and no Honor / Infamy of its own (points go through Deeds via the card)")
    check(code.count("task.wait(1)") == 1 and code.count("task.spawn") == 1, "one 1 s loop")
    check(code.count("Util.Random:NextNumber()") == 1, "one draw per kill (past the From count)")
    check(code.count('"Choice"') == 1, "gold has one source: Choice (never 2x)")
    config = read(SHARED / "Config.luau")
    block = config[config.find("-- #45 Lost & Found"):]
    block = block[: block.find("Config.ChoiceCard.Kinds.LostMedal")]
    bcode = "\n".join(l.split("--", 1)[0] for l in block.splitlines())
    check(not re.search(r"[가-힣]", bcode), "Config.LostFound block: English text only")
    check(config.count("Config.LostFound = {") == 1 and config.count("Config.Data.Defaults.LostFound") == 1, "Config.LostFound and its save default exist once")
    return count, failures


SUITE = Suite(
    mark="LOSTFOUND",
    fixture=ROOT / "tools/fixtures/lost_found_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-10/offline_dev3_lost_found_2026-10-10.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="#45: a per-player kill beat (nothing below 60 kills in a zone that has an item, rising evenly to sure at 100, "
             "then it starts again, no counting while holding, 3 finds a KST day, a free rider counts nothing); a find holds "
             "ONE thing (data.LostFound { Day, N, K, Holding }) and opens the item's saved ChoiceCard (no reward of its own, "
             "points via Deeds); the pick starts the walk: Good and a child's Evil to the Lost & Found bench (Crossroads, 10 "
             "studs of the kids' bench), a non-child's Evil to the player's own town (the vault); arriving (a 1 s loop) pays "
             "2 minutes of hunting at the player's level: Good = XP + 2 HP + 2 MP potions + the day's first scroll, Evil = "
             "gold; gold source Choice, XP capped by itself (never 2x); a full bag, a failing grant or payment pays nothing "
             "twice; the quest-list row Kind 'Find' with a guide; a broken save is repaired; OFF by default "
             "(Config.LostFound.Enabled).",
    limitations="The row's Kind 'Find' and its guide tap are client work (game dev 1); the four item icons are image session 2's. "
                "The numbers are PROPOSED (검수 decides). OFF until the quest window draws the row.",
)

if __name__ == "__main__":
    run(SUITE)
