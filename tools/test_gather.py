"""Gathering (GatherService, 게임성 개발 3, 2026-10-11), offline.

Contract docs/design/gather_server_2026-10-11.md (background gathering_2026-10-06.md): everyone holds the interact key at
a herb bush / ore rock (Config.Gather.Nodes, 54 spots in the meadow, the woods and the ruins) for one material (20% two);
the node rests 180 s for the gatherer only; the server checks the switch, the node, a living player with a class and a
side, the hold (>= 0.8 x the node's hold, began on this node), 12 studs, one a second, my rest, 400 a KST day and no hit
from another player during the hold; a full bag gives and counts nothing. Plant nodes may open the Shard Bloom (the shared
ChoiceCard: sure once from the 5th gather, else 8%, 3 a day, never over another card): Share = 2 + 1 to everyone within 40
studs (10 gifts a day each), Keep it all = 3, time up = 1. Notices are keys only (Net.NotifyKey), the prompts carry
ActionKey / ObjectKey and no words, the server never touches a prompt's Enabled. LootService.GrantItems (new) pays the
items like a drop. Runs the CURRENT Config, Util, LootService, Deeds, ChoiceCard and GatherService on
tools/fixtures/dev2_kit.luau + tools/fixtures/dev3_world.luau with tools/fixtures/gather_offline.luau and the installed
official Luau CLI. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources.

Usage: py tools/test_gather.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-11/offline_dev3_gather_2026-10-11.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "LOOT_SOURCE": SSS / "LootService.luau",
    "DEEDS_SOURCE": SSS / "Deeds.luau",
    "CARD_SOURCE": SSS / "ChoiceCard.luau",
    "GATHER_SOURCE": SSS / "GatherService.luau",
}
C, L, G = "CONFIG_SOURCE", "LOOT_SOURCE", "GATHER_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # --- the table
    ("config: on by default", C, "Config.Features.Gathering = false\n", "Config.Features.Gathering = true\n"),
    ("config: 500 a day", C, "\tDailyCap = 400,\n\tMinHoldRatio", "\tDailyCap = 500,\n\tMinHoldRatio"),
    ("config: 0.7 of the hold", C, "\tMinHoldRatio = 0.8,\n", "\tMinHoldRatio = 0.7,\n"),
    ("config: server range 15", C, "\tServerRange = 12,\n\tRegrow", "\tServerRange = 15,\n\tRegrow"),
    ("config: 120 s rest", C, "\tRegrow = 180,\n\tDouble", "\tRegrow = 120,\n\tDouble"),
    ("config: 30% double", C, "\tDouble = 0.2,\n\tHeavy", "\tDouble = 0.3,\n\tHeavy"),
    ("config: herbs hold 1 s", C, "HerbBush = { Item = \"Herb\", Hold = 1.5,", "HerbBush = { Item = \"Herb\", Hold = 1.0,"),
    ("config: copper is picked", C, "CopperRock = { Item = \"CopperOre\", Hold = 2.0, Action = \"Mine\",", "CopperRock = { Item = \"CopperOre\", Hold = 2.0, Action = \"Pick\","),
    ("config: rocks bloom", C, "CopperRock = { Item = \"CopperOre\", Hold = 2.0, Action = \"Mine\", Zone", "CopperRock = { Item = \"CopperOre\", Hold = 2.0, Action = \"Mine\", Plant = true, Zone"),
    ("config: bloom 10%", C, "Bloom = { Chance = 0.08,", "Bloom = { Chance = 0.10,"),
    ("config: sure at the 3rd", C, "FirstAt = 5, DailyMax = 3,", "FirstAt = 3, DailyMax = 3,"),
    ("config: 4 blooms a day", C, "FirstAt = 5, DailyMax = 3,", "FirstAt = 5, DailyMax = 4,"),
    ("config: share radius 50", C, "DailyMax = 3, Radius = 40,", "DailyMax = 3, Radius = 50,"),
    ("config: 20 gifts a day", C, "GiftDailyMax = 10, Item = \"CrownDust\"", "GiftDailyMax = 20, Item = \"CrownDust\""),
    ("config: a first hint again", C, "\t\tBloomWilt = \"The bloom closed up. +1 Crown Dust\",\n", "\t\tBloomWilt = \"The bloom closed up. +1 Crown Dust\",\n\t\tFirstHint = \"Hold to pick!\",\n"),
    ("config: herb sells for 2", C, "Name = \"Meadow Herb\", Sell = 1,", "Name = \"Meadow Herb\", Sell = 2,"),
    ("config: the gathered items out of the bag order", C, "\t\t\"Herb\", \"CopperOre\", \"OakLog\", \"Glowcap\", \"IronOre\", \"SilverOre\", \"MoonCrystal\", \"CrownDust\",\n", ""),
    ("config: share pays 3", C, "Good = { Label = \"Share it\", Reward = { Item = \"CrownDust\", N = 2 }", "Good = { Label = \"Share it\", Reward = { Item = \"CrownDust\", N = 3 }"),
    ("config: the card waits forever", C, "Config.ChoiceCard.Kinds.ShardBloom = {\n\tSeconds = 120,\n", "Config.ChoiceCard.Kinds.ShardBloom = {\n"),
    ("config: a spot on the crown road", C, "{ \"CopperRock\", 0.9273, 0.4583 }", "{ \"CopperRock\", 0.9273, 0.4917 }"),
    ("config: spot pos off by one edge", C, "return Vector3.new(z.Center.X - z.Size.X / 2 + u * z.Size.X, 0, z.Center.Z - z.Size.Z / 2 + v * z.Size.Z)",
     "return Vector3.new(z.Center.X - z.Size.X / 2 + u * z.Size.X, 0, z.Center.Z + v * z.Size.Z)"),
    ("config: no rate limit entry", C, "Config.RateLimits.Gather = 1\n", "Config.RateLimits.Gather = 0\n"),
    # --- nodes
    ("build: nodes with the switch off", G, "\tif not on() or ST.Folder then return end\n", "\tif ST.Folder then return end\n"),
    ("build: the prompt reaches 10", G, "prompt.MaxActivationDistance = num(G().PromptRange, 8)", "prompt.MaxActivationDistance = 10"),
    ("build: a sight line needed", G, "\tprompt.RequiresLineOfSight = false\n", ""),
    ("build: English words on the prompt", G, "\tprompt.ActionText = \"\"\n", "\tprompt.ActionText = def.Action\n"),
    ("build: no ObjectKey", G, "\tprompt:SetAttribute(\"ObjectKey\", \"Config.Loot.Items.\" .. def.Item .. \".Name\")\n", ""),
    ("build: Mine for everything", G, "(def.Action == \"Mine\" and \"Mine\" or \"Pick\")", "\"Mine\""),
    ("build: tagged spots ignored", G, "\t\tif not out[zone] then\n", "\t\tif true then\n"),
    ("build: the kit model ignored", G, "\tif src and src:IsA(\"Model\") then\n", "\tif false then\n"),
    ("build: nodes float at 0", G, "\tif ok and hit then return Vector3.new(pos.X, hit.Position.Y, pos.Z) end\n", ""),
    ("build: the ray sees the nodes", G, "\t\tlocal skip = { ST.Folder }\n", "\t\tlocal skip = {}\n"),
    ("build: the stand-in blocks players", G, "\tpart.CanCollide = false\n", "\tpart.CanCollide = true\n"),
    # --- one gather
    ("try: the switch not checked", G, "\tif not on() then return \"off\" end\n", ""),
    ("try: a KO'd player gathers", G, " or not Util.IsAlive(player) then\n\t\treturn \"state\"", " then\n\t\treturn \"state\""),
    ("try: no class needed", G, "or data.ClassChosen ~= true or not Config.Factions[data.Faction]", "or not Config.Factions[data.Faction]"),
    ("try: no side needed", G, "\t\tor data.Faction == \"None\" or not Util.IsAlive(player) then", "\t\tor not Util.IsAlive(player) then"),
    ("try: a hold on any node", G, "\tif type(hold) ~= \"table\" or hold.Id ~= id then return \"hold\" end\n", "\tif type(hold) ~= \"table\" then return \"hold\" end\n"),
    ("try: no hold needed", G, "\tif type(hold) ~= \"table\" or hold.Id ~= id then return \"hold\" end\n", "\tif type(hold) ~= \"table\" then hold = { Id = id, T0 = 0 } end\n"),
    ("try: a stale release counts", G, "\tif hold.Ended and now - hold.Ended > ST.StaleHold then return \"hold\" end\n", ""),
    ("try: any hold time", G, "< num(node.Def.Hold, 1.5) * num(cfg.MinHoldRatio, 0.8) then return \"hold\" end", "< 0 then return \"hold\" end"),
    ("try: no distance check", G, "\tif not root or (root.Position - node.Pos).Magnitude > num(cfg.ServerRange, 12) then return \"far\" end\n", ""),
    ("try: no rate limit", G, "\tif not Util.RateLimit(player, \"Gather\", num(Config.RateLimits.Gather, 1)) then return \"rate\" end\n", ""),
    ("try: no rest", G, "\tif rest and num(rest[id]) > os.time() then return \"rest\" end\n", ""),
    ("try: no daily cap", G, "\tif g.N >= num(cfg.DailyCap, 400) then\n", "\tif false then\n"),
    ("try: the cap notice every time", G, "\t\tif ST.CapSaid[player] ~= g.Day then\n", "\t\tif true then\n"),
    ("try: player hits do not cut", G, "\tif hold.Hit then\n", "\tif false then\n"),
    ("try: always one", G, "local n = rng:NextNumber() < num(cfg.Double, 0.2) and 2 or 1", "local n = 1"),
    ("try: a full bag still counts", G, "\tif got <= 0 then return \"full\" end\n", ""),
    ("try: the rest is 0", G, "\trest[id] = os.time() + num(cfg.Regrow, 180)\n", "\trest[id] = os.time()\n"),
    ("try: the day count never grows", G, "\tg.N += 1\n\tg.Total += 1\n", "\tg.Total += 1\n"),
    ("try: no artisan sparkle", G, "\tif data.Faction == \"Neutral\" then pcall(Net.Fx, player, \"Gather\", { Id = id, Artisan = true }) end\n", ""),
    ("try: no Gathered signal", G, "\tGatherService.Gathered:Fire(player, item, got, node.Kind)\n", ""),
    ("try: no GatherState", G, "\tsendState(player, data)\n\treturn \"ok\"\n", "\treturn \"ok\"\n"),
    ("try: the day never turns", G, "\tif num(g.Day) ~= day then\n", "\tif num(g.Day) == 0 then\n"),
    ("try: no first-gather log", G, "\tif g.Total == 1 and S.TelemetryService then", "\tif false and S.TelemetryService then"),
    ("heavy: logged every gather over", G, "\tif h.N == math.floor(num(G().Heavy, 200)) + 1 and S.TelemetryService then\n", "\tif h.N > math.floor(num(G().Heavy, 200)) and S.TelemetryService then\n"),
    ("state: the rest time is local", G, "\t\tif t > now then ready[id] = snow + (t - now) end\n", "\t\tif t > now then ready[id] = t end\n"),
    ("hit: monsters cut too", G, "\tif typeof(attacker) ~= \"Instance\" or num(amount) <= 0 then return end\n", "\tif num(amount) <= 0 then return end\n"),
    # --- the bloom
    ("bloom: rocks bloom", G, "if type(B) ~= \"table\" or not node.Def.Plant then return false end", "if type(B) ~= \"table\" then return false end"),
    ("bloom: the card's answer ignored", G, "\tif not ok or opened ~= true then return false end\n", "\tif not ok then return false end\n"),
    ("bloom: no daily max", G, "\tif g.Bloom >= num(B.DailyMax, 3) then return false end\n", ""),
    ("bloom: no sure first", G, "\tlocal sure = g.Total >= num(B.FirstAt, 5) and g.FirstBloom ~= true\n", "\tlocal sure = false\n"),
    ("bloom: the sure one again and again", G, "\tg.FirstBloom = true\n", ""),
    ("bloom: never counted", G, "\tg.Bloom += 1\n\tg.FirstBloom = true\n", "\tg.FirstBloom = true\n"),
    ("share: nobody gets one", G, "\tif side == \"Good\" then\n\t\tshare(player, bloom)\n", "\tif side == \"Good\" then\n"),
    ("share: the giver gets one too", G, "\t\tlocal r = other ~= giver and rootOf(other)\n", "\t\tlocal r = rootOf(other)\n"),
    ("share: any distance", G, "(r.Position - center).Magnitude <= num(B.Radius, 40) then", "true then"),
    ("share: no gift cap", G, "\t\t\tif g.Gift < num(B.GiftDailyMax, 10) then\n", "\t\t\tif true then\n"),
    ("share: keep it all shares", G, "\tif side == \"Good\" then\n\t\tshare(player, bloom)\n", "\tif side ~= \"None\" then\n\t\tshare(player, bloom)\n"),
    ("wilt: nothing at time up", G, "\telseif side == \"None\" then\n", "\telseif false then\n"),
    # --- 게임성 검수 10/12 (before the switch goes on)
    ("ready: a hold before ready is noted", G, "\tif not id or not on() or not S.PlayerService.IsReady(player) then return end\n", "\tif not id or not on() then return end\n"),
    ("ready: Try ignores ready", G, "\tif not data or not S.PlayerService.IsReady(player) or data.ClassChosen ~= true", "\tif not data or data.ClassChosen ~= true"),
    ("seat: seated players gather", G, "\tif hum and hum.Sit == true then return \"seated\" end\n", ""),
    ("jump: never blocks", G, "\tif os.clock() - num(ST.Jumped[player], -math.huge) < num(cfg.AfterJump, 3) then return \"moved\" end\n", ""),
    ("jump: never marked", G, "then ST.Jumped[p] = os.clock() end\n", "then end\n"),
    ("jump: 40 studs is a jump", C, "\tJumpStuds = 60,\n", "\tJumpStuds = 40,\n"),
    ("grant: counted from the returned rows", G, "\tlocal got = math.max(0, after - before)\n", "\tlocal got = okGrant and math.max(0, after - before) or 0\n"),
    ("share: around the giver", G, "\tlocal center = bloom and bloom.Pos\n", "\tlocal center = rootOf(giver) and rootOf(giver).Position or (bloom and bloom.Pos)\n"),
    ("share: KO'd players get one", G, "\t\tlocal data = r and S.PlayerService.IsReady(other) and Util.IsAlive(other) and getData(other)\n", "\t\tlocal data = r and S.PlayerService.IsReady(other) and getData(other)\n"),
    ("share: classless players get one", G, "\t\tif data and data.ClassChosen == true and (r.Position - center).Magnitude", "\t\tif data and (r.Position - center).Magnitude"),
    ("text: herbs sold at the Forge", C, 'Name = "Meadow Herb", Sell = 1, Color = Color3.fromRGB(140, 210, 255), Icon = "IconMeadowHerb", Source = "Gather", Desc = "Artisans craft with it." }', 'Name = "Meadow Herb", Sell = 1, Color = Color3.fromRGB(140, 210, 255), Icon = "IconMeadowHerb", Source = "Gather", Desc = "Sell it at the Forge." }'),
    ("text: the full line sends to the Forge", L, "\t\tif def.Kind == \"Material\" and def.Source ~= nil then fmt = TXT.ItemFullKeep or fmt end -- not sold at the Forge\n", ""),
    # --- LootService.GrantItems
    ("grant: 100 at once", L, "\t\tif type(id) == \"string\" and n >= 1 and n <= 99 then\n", "\t\tif type(id) == \"string\" and n >= 1 then\n"),
    # (no 'n >= 1 removed' mutation: addItem gives 0 for n <= 0, so it is equivalent)
    ("grant: no Loot Fx", L, "\t\tpcall(Net.Fx, player, \"Loot\", { Pos = typeof(pos) == \"Vector3\" and pos or nil, Items = gained })\n", ""),
    ("grant: Fx even when nothing fit", L, "\tif #gained > 0 then\n\t\tpublish(player, data)\n\t\tpcall(Net.Fx, player, \"Loot\", { Pos = typeof(pos)", "\tif true then\n\t\tpublish(player, data)\n\t\tpcall(Net.Fx, player, \"Loot\", { Pos = typeof(pos)"),
]


def static() -> tuple[int, list[str]]:
    count, failures = 0, []

    def check(ok: bool, name: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(name)

    main = read(SSS / "Main.server.luau")
    init = re.search(r"local INIT_ORDER = \{(.*?)\n\}", main, re.S)
    start = re.search(r"local START_ORDER = \{(.*?)\n\}", main, re.S)
    names_i = re.findall(r'"(\w+)"', strip_comments(init.group(1))) if init else []
    names_s = re.findall(r'"(\w+)"', strip_comments(start.group(1))) if start else []
    check("GatherService" in names_i and names_i.index("GatherService") > names_i.index("ChoiceCard")
          and names_i.index("GatherService") > names_i.index("LootService"),
          "Main INIT_ORDER has GatherService after LootService and ChoiceCard")
    check("GatherService" in names_s and names_s.index("GatherService") < names_s.index("PlayerService")
          and names_s.index("GatherService") > names_s.index("ChoiceCard"),
          "Main START_ORDER has GatherService after ChoiceCard and before PlayerService")
    net = read(SHARED / "Net.luau")
    names = re.search(r"Net\.Names = \{(.*?)\n\}", net, re.S)
    check(bool(names) and '"GatherState"' in strip_comments(names.group(1)), "Net.Names has the s->c remote GatherState")
    gather = strip_comments(read(SSS / "GatherService.luau"))
    check("Net.Notify(" not in gather and "Net.NotifyAll" not in gather and "Net.NotifyKey" in gather,
          "GatherService sends notices by key only (Net.NotifyKey)")
    check(".Enabled" not in gather, "GatherService never touches a prompt's Enabled")
    check("Players.PlayerRemoving:Connect(forget)" in gather and "S.PlayerService.PlayerLeaving:Connect(forget)" in gather,
          "per-player state is dropped on both leave paths (PlayerLeaving and Players.PlayerRemoving)")
    check(not re.search(r"MarketplaceService|PromptPurchase|Robux|AddXP|AddBankGold|AddCarriedGold|GrantFirstWeapon|Potion",
                        gather), "gathering pays no XP, gold, weapon or potion and has no purchase path")
    check("MonsterService" not in gather and "AutoCombat" not in gather, "no auto-combat path into gathering")
    check(not re.search(r'"[A-Z][a-z]+ [a-z]+ [a-z]+[^"]*"', gather), "no English sentence in GatherService (keys only)")
    loot = read(SSS / "LootService.luau")
    check("function LootService.GrantItems(player, list, pos, source)" in loot, "LootService.GrantItems exists")
    config = read(SHARED / "Config.luau")
    check("FirstHint" not in config.split("Config.Gather = {", 1)[1].split("Config.RateLimits.Gather", 1)[0],
          "no first-time hint text in Config.Gather (A23-130, 게임성 개발 4)")
    return count, failures


SUITE = Suite(
    mark="GATHER",
    fixture=ROOT / "tools/fixtures/gather_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-11/offline_dev3_gather_2026-10-11.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="Gathering (docs/design/gather_server_2026-10-11.md): switch Config.Features.Gathering off; 54 nodes (meadow 12 "
             "herb + 8 copper, woods 8 oak + 8 glowcap + 6 iron, ruins 6 silver + 6 moon crystal) in workspace.Map."
             "GatherNodes, WorldKit GatherSpot parts replacing a zone's list, a GatherKit model or a walk-through stand-in "
             "on the ray-found ground; prompt GatherPrompt (the node's hold, 8 studs, no sight line, no words, ActionKey / "
             "ObjectKey, Enabled never touched); a gather = switch on, our node, alive + class + side, hold >= 0.8 x and "
             "began on this node (a release <= 1 s before the trigger), <= 12 studs, 1 a second, my 180 s rest, 400 a KST "
             "day (one DailyCap notice), no player hit (monsters fine), a full bag = nothing; 20% two; Gathered, "
             "GatherState { Ready (server time), N, Cap }, the artisan Fx, GatherFirst / GatherHeavy (once past 200 an "
             "hour); the Shard Bloom on plants (sure from the 5th gather, 8%, 3 a day, not over an open card): Share = 2 "
             "+ 1 to everyone within 40 studs (10 gifts a day), Keep = 3, time up = 1 + BloomWilt, points through Deeds "
             "(none for artisans); LootService.GrantItems (known ids, 1..99, drop-shaped rows, one Loot Fx).",
    limitations="No real ProximityPrompt / hold UI (the prompt events are fired by the test), no Studio raycast against the "
                "real map, no client (GatherView is 게임성 개발 4's dev4-gather). Quests that count gathers (Gather goal) "
                "and the crafting recipes that use the materials come later.",
)

if __name__ == "__main__":
    run(SUITE)
