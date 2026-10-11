"""Artisan crafting (CraftService, 게임성 개발 3, 2026-10-12), offline.

Contract docs/design/craft_server_2026-10-12.md (게임성 검수 OK 10/12; the hammer = 게임성 개발 4's shared
src/ReplicatedStorage/Shared/CraftMini.luau, tested by tools/test_craft_mini.py): only artisans (Neutral) craft, only their
role's recipes (Warrior Smith, Mage Alch, Archer Tame), within 12 studs of their workbench (tag CraftStation, else the
Crossroads anvil), auto combat off, 6 starts a minute, craft level / materials / gold / room checked, the gold (source
Craft) and materials taken at the start with Craft.Pend in the save; the hammer on a fixed schedule from StartAt =
server time + CraftMini.T.Lead: CraftStrike(id, i, ms) on a press notes { Ms, At } once per ring, CraftFinish(id) grades
with CraftMini.Accept (an arrival that does not fit the claimed ms is a Miss, a missing strike is a Miss); five equal
offsets +0; Skip = Finish at once = +0; time-up, leave, KO = +0; a join with Pend finishes it at +0 (stays pending while
there is no room); the weapon goes to the spares (LootService.AddSpare, 게임성 개발 2; weapon recipes off without it, W7 /
W9 off until their drops and T9 exist); craft XP per role 40 x Lv^1.5 up to Lv30, never doubled; CraftSession /
CraftResult / CraftInfo; notices are keys only. Runs the CURRENT Config, Util, CraftMini, LootService and CraftService on
tools/fixtures/dev2_kit.luau + tools/fixtures/dev3_world.luau with tools/fixtures/craft_offline.luau and the installed
official Luau CLI. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources.

Usage: py tools/test_craft.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-12/offline_dev3_craft_2026-10-12.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "CRAFTMINI_SOURCE": SHARED / "CraftMini.luau",
    "LOOT_SOURCE": SSS / "LootService.luau",
    "CRAFT_SOURCE": SSS / "CraftService.luau",
}
C, R = "CONFIG_SOURCE", "CRAFT_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # --- the table (the hammer's own numbers: tools/test_craft_mini.py)
    ("config: on by default", C, "Config.Features.Crafting = false\n", "Config.Features.Crafting = true\n"),
    ("config: archers are blacksmiths", C, "Roles = { Warrior = \"Smith\", Mage = \"Alch\", Archer = \"Tame\" },", "Roles = { Warrior = \"Smith\", Mage = \"Alch\", Archer = \"Smith\" },"),
    ("config: Lv40", C, "\tMaxLv = 30,\n\tXPBase = 40,", "\tMaxLv = 40,\n\tXPBase = 40,"),
    ("config: XP x 50", C, "\tXPBase = 40,\n\tXPExp = 1.5,", "\tXPBase = 50,\n\tXPExp = 1.5,"),
    ("config: range 15", C, "\tRange = 12, -- studs from the role's workbench", "\tRange = 15, -- studs from the role's workbench"),
    ("config: 10 starts a minute", C, "\tStartsPerMinute = 6,\n", "\tStartsPerMinute = 10,\n"),
    ("config: W1 costs 20", C, "Tier = 1, Lv = 1, Gold = 10,", "Tier = 1, Lv = 1, Gold = 20,"),
    ("config: W3 at craft Lv1", C, "Tier = 3, Lv = 5, Gold = 200,", "Tier = 3, Lv = 1, Gold = 200,"),
    ("config: Sea Shell back in W3", C, "Mats = { SlimeCore = 6, Jelly = 20, CopperOre = 10 }", "Mats = { SlimeCore = 6, Jelly = 20, SeaShell = 10 }"),
    ("config: XP at Lv30 goes on", C, "\tif l ~= l or l >= K.MaxLv then return 0 end\n", "\tif l ~= l then return 0 end\n"),
    # --- recipes on / off
    ("recipe: unknown materials allowed", R, "\t\tif not Config.Loot.Items[item] then return nil end\n", ""),
    ("recipe: weapons without AddSpare", R, "\t\tif not (L and type(L.AddSpare) == \"function\" and type(L.SpareRoom) == \"function\" and Config.Weapons[r.Tier]) then return nil end\n", ""),
    # --- start
    ("start: switch not checked", R, "\tif not on() then return \"off\" end\n", ""),
    ("start: anyone crafts", R, "\tif type(data) ~= \"table\" or data.Faction ~= \"Neutral\" or data.ClassChosen ~= true then return nil end\n\treturn K().Roles[data.Class]\n", "\treturn K().Roles[data.Class]\n"),
    ("start: any role's recipe", R, "\tif not role or role ~= r.Role then\n", "\tif not role then\n"),
    ("start: two sessions", R, "\tif ST.Open[player] or type(craftOf(data).Pend) == \"table\" then\n", "\tif false then\n"),
    ("start: no minute cap", R, "\tif #recent >= K().StartsPerMinute then\n", "\tif false then\n"),
    ("start: auto combat allowed", R, "\tif player:GetAttribute(\"AutoCombatUnlocked\") == true and player:GetAttribute(\"AutoCombatEnabled\") == true then\n", "\tif false then\n"),
    ("start: no distance", R, "\tif not root or not bench or (root.Position - bench.Position).Magnitude > K().Range then\n", "\tif not root or not bench then\n"),
    ("start: the tag ignored", R, "\t\tif part:IsA(\"BasePart\") and part:GetAttribute(\"Role\") == role then\n", "\t\tif false then\n"),
    ("start: no level check", R, "\tif roleRec(c, role).Lv < r.Lv then\n", "\tif false then\n"),
    ("start: no materials check", R, "\tif not hasMats(data, r) then\n", "\tif false then\n"),
    ("start: no room check", R, "\tif not room(player, data, r) then\n", "\tif false then\n"),
    ("start: gold never paid", R, "\tif not S.ProgressionService.SpendGold(player, r.Gold, \"Craft\") then\n", "\tif false then\n"),
    ("start: materials kept", R, "\t\tif not S.LootService.TakeItem(player, item, n) then Util.Warn(TAG, \"take \" .. item .. \" failed after the check\") end\n", ""),
    ("start: nothing pending in the save", R, "\tc.Pend = { Id = id, Plus = -1, Gold = r.Gold, Mats = table.clone(r.Mats) }\n", ""),
    ("start: no lead time", R, "StartAt = serverNow() + T.Lead, Strikes = {},", "StartAt = serverNow(), Strikes = {},"),
    ("start: no time-up", R, "\t\tif ST.Open[player] == sess then closeAtZero(player, \"Timeout\") end\n", ""),
    ("start: the stuck pending one never retried", R, "\tif not ST.Open[player] and type(craftOf(data).Pend) == \"table\" then CraftService.Settle(player, data) end\n", ""),
    # --- strikes
    ("strike: any session id", R, "\tif not sess or sess.Id ~= sid or sess.Done then return \"session\" end\n\tif type(i)", "\tif not sess or sess.Done then return \"session\" end\n\tif type(i)"),
    ("strike: ring 6 taken", R, "or i < 1 or i > CraftMini.T.Strikes then return \"ring\" end", "or i < 1 or i > 99 then return \"ring\" end"),
    ("strike: a second press replaces the first", R, "\tif sess.Strikes[i] then return \"again\" end\n", ""),
    ("strike: any offset size", R, "or math.abs(ms) > CraftMini.T.MaxMs then return \"ms\" end", "then return \"ms\" end"),
    ("strike: the client's own time", R, "\tsess.Strikes[i] = { Ms = ms, At = serverNow(), Ping = pingMs(player) }\n", "\tsess.Strikes[i] = { Ms = ms, At = CraftMini.Target(sess.StartAt, i) + ms / 1000, Ping = pingMs(player) }\n"),
    # --- finish
    ("finish: any lie fits (huge ping)", R, "\tlocal grades, _, plus = CraftMini.Accept(sess.Strikes, sess.StartAt, pingMs(player), sess.StartPing)\n", "\tlocal grades, _, plus = CraftMini.Accept(sess.Strikes, sess.StartAt, 1000, sess.StartPing)\n"),
    ("finish: the ping now ignored", R, "\tlocal grades, _, plus = CraftMini.Accept(sess.Strikes, sess.StartAt, pingMs(player), sess.StartPing)\n", "\tlocal grades, _, plus = CraftMini.Accept(sess.Strikes, sess.StartAt, 0, sess.StartPing)\n"),
    ("finish: the start ping ignored", R, "\tlocal grades, _, plus = CraftMini.Accept(sess.Strikes, sess.StartAt, pingMs(player), sess.StartPing)\n", "\tlocal grades, _, plus = CraftMini.Accept(sess.Strikes, sess.StartAt, pingMs(player))\n"),
    ("finish: a wrong schedule", R, "\tlocal grades, _, plus = CraftMini.Accept(sess.Strikes, sess.StartAt, pingMs(player), sess.StartPing)\n", "\tlocal grades, _, plus = CraftMini.Accept(sess.Strikes, sess.StartAt - 1, pingMs(player), sess.StartPing)\n"),
    ("strike: the ping then not kept", R, "\tsess.Strikes[i] = { Ms = ms, At = serverNow(), Ping = pingMs(player) }\n", "\tsess.Strikes[i] = { Ms = ms, At = serverNow() }\n"),
    ("finish: twice", R, "\tsess.Done = true\n\tST.Open[player] = nil\n\tlocal grades", "\tlocal grades"),
    ("finish: bots get their +N", R, "\t\tif same then\n\t\t\tplus = 0\n", "\t\tif same then\n"),
    ("finish: no strike-d metric", R, "\tif dN > 0 then tele(player, \"CraftStrikeD\", math.floor(dMax + 0.5), math.floor(dMin + 0.5), dN) end\n", ""),
    ("finish: d measured the wrong way", R, "\t\t\tlocal d = (s.At - CraftMini.Target(sess.StartAt, i)) * 1000 - s.Ms\n", "\t\t\tlocal d = s.Ms - (s.At - CraftMini.Target(sess.StartAt, i)) * 1000\n"),
    ("finish: no mismatch log", R, "\tif mismatch > 0 then tele(player, \"CraftMismatch\", mismatch) end\n", ""),
    # --- the end
    ("end: Pend never cleared", R, "\tc.Pend = nil\n\tc.Made[recipeId]", "\tc.Made[recipeId]"),
    ("end: Made not counted", R, "\tc.Made[recipeId] = math.floor(num(c.Made[recipeId])) + 1\n", ""),
    ("end: no XP", R, "\tlocal lv, up = addXP(c, r.Role, xp)\n", "\tlocal lv, up = roleRec(c, r.Role).Lv, false\n"),
    ("xp: the pass ignored (A23-139)", R, "xp = math.floor(num(r.XP) * (okPass and num(pass, 1) or 1))", "xp = math.floor(num(r.XP))"),
    ("xp: the hunting bonus used", R, "ps.PassMult(player, \"XP2\")", "ps.GetXPMult(player)"),
    ("xp: any side gets craft XP (A23-139)", R, "\tif roleOf(data) == r.Role then\n\t\tlocal ps = S.ProgressionService", "\tif true then\n\t\tlocal ps = S.ProgressionService"),
    ("end: one level at most", R, "\twhile rr.Lv < K().MaxLv do\n", "\tif rr.Lv < K().MaxLv then\n"),
    ("end: no Crafted signal", R, "\tCraftService.Crafted:Fire(player, recipeId, plus)\n", ""),
    ("end: no CraftInfo after", R, "\t\tsendInfo(player, data)\n\tend\n\tCraftService.Crafted", "\tend\n\tCraftService.Crafted"),
    ("end: leave loses the craft", R, "\t\tcloseAtZero(player, \"Leave\")\n", ""),
    ("end: KO loses the craft", R, "\t\t\tcloseAtZero(player, \"KO\")\n", ""),
    ("end: a stopped craft never finishes", R, "if type(data.Craft) == \"table\" and type(data.Craft.Pend) == \"table\" and CraftService.Settle(player, data) == \"wait\" then", "if false then"),
    ("end: an unknown Pend stays", R, "\tif type(K().Recipes[p.Id]) ~= \"table\" then\n\t\tc.Pend = nil\n", "\tif type(K().Recipes[p.Id]) ~= \"table\" then\n"),
    # --- remotes
    ("refund: no gold back", R, "\t\tif gold > 0 then pcall(S.ProgressionService.AddBankGold, player, gold, \"CraftRefund\") end\n", ""),
    ("refund: no materials back", R, "\t\tif #list > 0 then pcall(S.LootService.GrantItems, player, list, nil, \"CraftRefund\") end\n", ""),
    ("refund: rows over 99", R, "\t\t\t\ttable.insert(list, { Id = item, N = math.min(99, left) })\n", "\t\t\t\ttable.insert(list, { Id = item, N = left })\n"),
    ("refund: a doubled source", R, "pcall(S.ProgressionService.AddBankGold, player, gold, \"CraftRefund\")", "pcall(S.ProgressionService.AddBankGold, player, gold, \"Monster\")"),
    ("pend: the earned +N forgotten", R, "\tif type(c.Pend) == \"table\" and c.Pend.Id == recipeId then c.Pend.Plus = plus end\n", ""),
    ("pend: a waiting craft always +0", R, "return complete(player, data, p.Id, math.max(0, math.floor(num(p.Plus))), misses(), 0) and \"done\" or \"wait\"", "return complete(player, data, p.Id, 0, misses(), 0) and \"done\" or \"wait\""),
    ("off: the join writes when off", R, "\t\tif type(data) ~= \"table\" or not on() then return end\n", "\t\tif type(data) ~= \"table\" then return end\n"),
    ("item: a part of it given", R, "\tif before + n > Config.Loot.ItemCap then return false end -- never a part of it\n", ""),
    ("gear: no caps at the end", R, "\t\tif sum >= ST.GearSum or math.floor(num(own[key])) >= Config.SaveV4.OwnKeyMax then return false end\n", ""),
    ("gear: only the sum at the end", R, "\t\tif sum >= ST.GearSum or math.floor(num(own[key])) >= Config.SaveV4.OwnKeyMax then return false end\n", "\t\tif sum >= ST.GearSum then return false end\n"),
    ("finish limit: any id uses it", R, "\tif not sess or sess.Id ~= sid then return end -- a stale / wrong id never uses up the limit of the real Finish\n", ""),
    ("remote: extra arguments taken", R, "\tif select(\"#\", ...) ~= 1 then return end\n\tlocal id = ...\n", "\tlocal id = ...\n"),
    ("remote: no start rate limit", R, "\tif not Util.RateLimit(player, \"CraftStart\", num(Config.RateLimits.CraftStart, 3)) then return end\n", ""),
    ("remote: a two-argument Finish taken", R, "\tif select(\"#\", ...) ~= 1 then return end\n\tlocal sid = ...\n", "\tlocal sid = ...\n"),
    ("remote: a text strike id taken", R, "\tlocal sid, i, ms = ...\n\tif type(sid) ~= \"number\" then return end\n", "\tlocal sid, i, ms = ...\n\tsid = tonumber(sid) or sid\n"),
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
    ni = re.findall(r'"(\w+)"', strip_comments(init.group(1))) if init else []
    ns = re.findall(r'"(\w+)"', strip_comments(start.group(1))) if start else []
    check("CraftService" in ni and ni.index("CraftService") > ni.index("LootService") and ni.index("CraftService") > ni.index("ShopService"),
          "Main INIT_ORDER has CraftService after LootService and ShopService")
    check("CraftService" in ns and ns.index("CraftService") < ns.index("PlayerService"), "Main START_ORDER has CraftService before PlayerService")
    net = read(SHARED / "Net.luau")
    names = re.search(r"Net\.Names = \{(.*?)\n\}", net, re.S)
    body = strip_comments(names.group(1)) if names else ""
    for n in ("CraftStart", "CraftStrike", "CraftFinish", "CraftSession", "CraftResult", "CraftInfo"):
        check(f'"{n}"' in body, f"Net.Names has {n}")
    craft = strip_comments(read(SSS / "CraftService.luau"))
    check("Net.Notify(" not in craft and "Net.NotifyAll" not in craft and "Net.NotifyKey" in craft, "CraftService sends notices by key only")
    check(not re.search(r"MarketplaceService|PromptPurchase|Robux|AddXP|GetXPMult|GetGoldMult", craft),
          "no purchase path, no hunting XP, no pass multiplier in crafting")
    check(not re.search(r'"[A-Z][a-z]+ [a-z]+ [a-z]+[^"]*"', craft), "no English sentence in CraftService (keys only)")
    check('require(Shared:WaitForChild("CraftMini"))' in craft and not re.search(r"Lag|Windows|PlusAt|Ring = \d", craft.split("local CraftService = {}", 1)[1].replace("T.Ring", "")),
          "CraftService takes the hammer's numbers and rules from Shared/CraftMini only")
    config = read(SHARED / "Config.luau")
    check("Config.Features = { NeutralFaction = false, Market = false, StatPoints = false }" in config,
          "the Config.Features line is untouched (other suites' mutations use it)")
    return count, failures


SUITE = Suite(
    mark="CRAFT",
    fixture=ROOT / "tools/fixtures/craft_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-12/offline_dev3_craft_2026-10-12.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="Crafting (docs/design/craft_server_2026-10-12.md, 게임성 검수 OK 10/12; the hammer = Shared/CraftMini): switch Config.Features.Crafting off; "
             "Neutral only, the role's recipes only (Warrior Smith / Mage Alch / Archer Tame); 12 studs from the role's "
             "workbench (tag CraftStation, else the anvil); auto combat off; 6 starts a minute; craft Lv / materials / gold / "
             "room; gold (Craft) + materials at the start, Craft.Pend saved; CraftSession { Id, Recipe, 5, 1.2, 0.35, StartAt "
             "= server + 0.8 }; CraftStrike timed by the server, in order, >= 0.25 s apart; a claim beyond 250 ms + jitter "
             "(CraftMini: server ms - client ms outside -50 .. 250 + 1.5 x the biggest ping) = Miss; |ms - 40| <= 70 / 130 / 200; points "
             ">= 13 +2, >= 9 +1; five equal claims +0 (CraftBot); time-up / leave / KO +0; Pend at join finishes at +0 "
             "(stays while there is no room, retried at the next start); the result to the spares (AddSpare); W7 / W9 "
             "off until Clatter Gem / Royal Jelly / T9; craft XP per role 40 x Lv^1.5, Lv30 cap, not doubled; CraftResult "
             "/ CraftInfo; key-only notices.",
    limitations="AddSpare / SpareRoom are doubles until 게임성 개발 2's C1 (Spares, v4); gear (⑥), tonics (④) and pet "
                "treats (⑤) add recipe rows later; the client hammer (게임성 개발 4) is played by the test from the offsets; "
                "no real network jitter. Artisan fame (Rep, ⑦) is not counted yet.",
)

if __name__ == "__main__":
    run(SUITE)
