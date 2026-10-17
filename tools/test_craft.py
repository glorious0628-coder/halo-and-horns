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
    # A23-219 craft tools + the Blessed Scroll (게임성 개발 2)
    ("bless: no room check before the Blessed Scroll", R, "Config.BagUsed(data) + slots <= Config.BagSlotsOf(data) then\n\t\t\tpcall(", "true then\n\t\t\tpcall("),
    ("bless: the old partial pay (false after the plain ones)", R, "\t\t\t\treturn true\n\t\t\tend\n\t\tend\n\tend\n", "\t\t\t\treturn false\n\t\t\tend\n\t\tend\n\tend\n"),
    ("bless: the roll ignores the bag", R, "if fits and b > 0 and", "if b > 0 and"),
    ("tool: no pending-craft gate", R, "\tif ST.Open[player] or type(c.Pend) == \"table\" then\n", "\tif ST.Open[player] then\n"),
    ("tool: no auto gate", R, "\t\treturn \"auto\"\n\tend\n\tlocal T = K().Tools\n", "\tend\n\tlocal T = K().Tools\n"),
    ("tools: a fail lowers the tool", R, "\t\tc[\"Tool\" .. role] = now + 1 -- saved with the costs (one write)\n\tend\n",
     "\t\tc[\"Tool\" .. role] = now + 1 -- saved with the costs (one write)\n\telse\n\t\tc[\"Tool\" .. role] = math.max(0, now - 1)\n\tend\n"),
    ("tools: the extra taken on a fail too", R, "\tlocal ok = ST.Rng:NextNumber() < cost.P\n\tif ok then\n\t\tfor item, n in cost.Extra do",
     "\tlocal ok = ST.Rng:NextNumber() < cost.P\n\tdo\n\t\tfor item, n in cost.Extra do"),
    ("tools: the extra not checked before", R, "\tfor item, n in cost.Extra do need[item] = (need[item] or 0) + n end\n", ""),
    ("tools: no level gate", R, "\tif roleRec(c, role).Lv < cost.Lv then\n\t\tnotify(player, \"NeedLevel\")\n\t\treturn \"level\"\n\tend\n\t-- everything",
     "\t-- everything"),
    ("tools: no bench check", R, "\tif not nearBench(player, role) then\n\t\tnotify(player, \"Far\")\n\t\treturn \"far\"\n\tend\n\tif roleRec(c, role).Lv < cost.Lv",
     "\tif roleRec(c, role).Lv < cost.Lv"),
    ("tools: past +10", R, "local cost = now < math.floor(num(T.Max, 10)) and CraftService.ToolCost(role, now + 1) or nil",
     "local cost = CraftService.ToolCost(role, now + 1) or CraftService.ToolCost(role, 10)"),
    ("tools: the band one too high", R, "local band = target <= 3 and 1 or target <= 6 and 2 or 3", "local band = target <= 2 and 1 or target <= 5 and 2 or 3"),
    ("tools: +7 at 60%", C, "{ Lv = 10, P = 0.50, Gold = 2500,", "{ Lv = 10, P = 0.60, Gold = 2500,"),
    ("tools: a nested Tool table saved", R, "\t\tc[\"Tool\" .. role] = now + 1", "\t\tc.Tool = { [role] = now + 1 }; c[\"Tool\" .. role] = now + 1"),
    ("bless: every scroll blessed", R, "{ { Id = bItem, N = 1 } }, nil, \"Craft\")", "{ { Id = bItem, N = n } }, nil, \"Craft\")"),
    ("bless: rolled at the end, not the start", R, "Bound = next(bound) ~= nil and bound or nil, Bless = bless }", "Bound = next(bound) ~= nil and bound or nil }"),
    ("bless: the kit's +N ignored", R, "T.Bless[toolOf(c, role)]", "T.Bless[10]"),
    ("bless: Enh70B is +1", C, "Chance = 0.7, Plus = 2, Color = Color3.fromRGB(255, 225, 120)", "Chance = 0.7, Plus = 1, Color = Color3.fromRGB(255, 225, 120)"),
    ("bless: the repair drops Pend.Bless", C, "\t\t\tBless = p.Bless == true or nil } -- A23-219", "\t\t\tBless = nil } -- A23-219"),
    ("tools: the repair keeps 12", C, "local v = V4.int(src[k], 0, max)", "local v = V4.int(src[k], 0, 99)"),
    ("⑤: Crafting back on reads nobody", "CRAFT_SOURCE", "\t\t\tif k ~= \"Crafting\" then return end\n", "\t\t\tdo return end\n"),
    ("bench: prompts stay when switched off", "CRAFT_SOURCE", "\t\t\t\t\tpcall(function() prompt:Destroy() end)\n", ""),
    ("GPT ①: SpareRoom ignores the freed slots", "LOOT_SOURCE", "Config.BagUsed(data) - math.max(0, math.floor(num(freed))) >= Config.BagSlotsOf(data) then return false end",
     "Config.BagUsed(data) >= Config.BagSlotsOf(data) then return false end"),
    ("GPT ①: a weapon recipe frees no slot", "CRAFT_SOURCE", "\t\t\tlocal ok, yes = pcall(S.LootService.SpareRoom, player, r.Tier, plus, freed)", "\t\t\tlocal ok, yes = pcall(S.LootService.SpareRoom, player, r.Tier, plus, 0)"),
    # 장인 ④ (2026-10-14): the benches
    ("bench: a second one over WorldKit's", R, "\t\tif type(role) == \"string\" then have[role] = true end\n", ""),
    ("bench: not tagged", R, "\t\t\tCollectionService:AddTag(part, K().StationTag)\n", ""),
    ("bench: none while crafting is off", R, "local function ensureBenches()\n\tif type(Config.Craft) ~= \"table\" then return false end\n", "local function ensureBenches()\n\tif not on() then return false end\n"),
    ("bench: a prompt while crafting is off", R, "\tif not on() or typeof(part) ~= \"Instance\"", "\tif typeof(part) ~= \"Instance\""),
    # 장인 ⑤ (2026-10-14): potions
    ("potion: any potion name", R, "\t\tif type(r.Potion) ~= \"string\" or not Config.PotionStockKey(r.Potion) then return nil end\n", ""),
    ("potion: no cap at the start", R, "\t\treturn key ~= nil and have + math.max(1, math.floor(num(r.N, 1))) + 2 <= Config.Vitals.PotionInventoryCap\n", "\t\treturn key ~= nil\n"),
    ("potion: the hammer's +N lost", R, "\t\tlocal n = math.max(1, math.floor(num(r.N, 1))) + math.max(0, math.floor(num(plus)))\n\t\tlocal key = Config.PotionStockKey(r.Potion)",
     "\t\tlocal n = math.max(1, math.floor(num(r.N, 1)))\n\t\tlocal key = Config.PotionStockKey(r.Potion)"),
    ("potion: the scroll from Lv1", C, "AS1 = { Role = \"Alch\", Kind = \"Item\", Item = \"Enh70\", N = 1, Lv = 3,", "AS1 = { Role = \"Alch\", Kind = \"Item\", Item = \"Enh70\", N = 1, Lv = 1,"),
    # bag slots (2026-10-14)
    ("bag: a new-kind result ignores the slots", R, "\tif have < 1 and def and Config.BagSlots.Counts[def.Kind] then\n", "\tif false then\n"),
    ("bag: a used-up material frees nothing", R, "held >= 1 and held <= n then freed += 1 end\n\t\tend\n\t\tif Config.BagUsed",
     "held >= 1 and held < n then freed += 1 end\n\t\tend\n\t\tif Config.BagUsed"),
    ("bag: one slot fewer at the craft", R, "if Config.BagUsed(data) - freed >= Config.BagSlotsOf(data) then return false end",
     "if Config.BagUsed(data) - freed >= Config.BagSlotsOf(data) - 1 then return false end"),
    # --- the table (the hammer's own numbers: tools/test_craft_mini.py)
    ("config: on by default", C, "Config.Features.Crafting = false\n", "Config.Features.Crafting = true\n"),
    ("config: archers are blacksmiths", C, "Roles = { Warrior = \"Smith\", Mage = \"Alch\", Archer = \"Tame\" },", "Roles = { Warrior = \"Smith\", Mage = \"Alch\", Archer = \"Smith\" },"),
    ("config: Lv40", C, "\tMaxLv = 30,\n\tXPBase = 40,", "\tMaxLv = 40,\n\tXPBase = 40,"),
    ("config: XP x 50", C, "\tXPBase = 40,\n\tXPExp = 1.5,", "\tXPBase = 50,\n\tXPExp = 1.5,"),
    ("config: range 15", C, "\tRange = 12, -- studs from the role's workbench", "\tRange = 15, -- studs from the role's workbench"),
    ("config: 10 starts a minute", C, "\tStartsPerMinute = 6,\n", "\tStartsPerMinute = 10,\n"),
    ("config: W2 costs 80", C, "Tier = 2, Lv = 1, Gold = 40,", "Tier = 2, Lv = 1, Gold = 80,"),
    ("config: W3 at craft Lv1", C, "Tier = 3, Lv = 5, Gold = 200,", "Tier = 3, Lv = 1, Gold = 200,"),
    ("config: Sea Shell back in W3", C, "Mats = { SlimeCore = 4, Jelly = 18, CopperOre = 8 }", "Mats = { SlimeCore = 4, Jelly = 18, SeaShell = 8 }"),
    ("config: XP at Lv30 goes on", C, "\tif l ~= l or l >= K.MaxLv then return 0 end\n", "\tif l ~= l then return 0 end\n"),
    # --- recipes on / off
    ("recipe: unknown materials allowed", R, "\t\tif not Config.Loot.Items[item] then return nil end\n", ""),
    ("recipe: gear without the gear switch", R, "\t\tif not Config.FeatureOn(\"Gear\") or type(r.Slot) ~= \"string\"", "\t\tif type(r.Slot) ~= \"string\""),
    ("recipe: weapons without AddSpare", R, "\t\tif not (L and type(L.AddSpare) == \"function\" and type(L.SpareRoom) == \"function\" and Config.Weapons[r.Tier]) then return nil end\n", ""),
    # --- start
    ("start: switch not checked", R, "\tif not on() then return \"off\" end\n", ""),
    ("start: anyone crafts", R, "\tif type(data) ~= \"table\" or data.Faction ~= \"Neutral\" or data.ClassChosen ~= true then return nil end\n\treturn K().Roles[data.Class]\n", "\treturn K().Roles[data.Class]\n"),
    ("start: any role's recipe", R, "\tif not role or role ~= r.Role then\n", "\tif not role then\n"),
    ("start: two sessions", R, "\tif ST.Open[player] or type(craftOf(data).Pend) == \"table\" then\n", "\tif false then\n"),
    ("start: no minute cap", R, "\tif #recent >= K().StartsPerMinute then\n", "\tif false then\n"),
    ("start: auto combat allowed", R, "\t\treturn \"auto\"\n\tend\n\tif not nearBench(player, role) then\n", "\tend\n\tif not nearBench(player, role) then\n"),
    ("start: no distance", R, "\tif not root or not bench or (root.Position - bench.Position).Magnitude > K().Range then return nil end\n", "\tif not root or not bench then return nil end\n"),
    ("start: the tag ignored", R, "\t\tif part:IsA(\"BasePart\") and part:GetAttribute(\"Role\") == role then\n", "\t\tif false then\n"),
    ("start: no level check", R, "\tif roleRec(c, role).Lv < r.Lv then\n", "\tif false then\n"),
    ("start: no materials check", R, "\tif not hasMats(data, r) then\n", "\tif false then\n"),
    ("start: no room check", R, "\tif not room(player, data, r) then\n", "\tif false then\n"),
    ("start: gold never paid", R, "\tif not S.ProgressionService.SpendGold(player, r.Gold, \"Craft\") then\n", "\tif false then\n"),
    ("start: materials kept", R, "\t\tif not S.LootService.TakeItem(player, item, n) then\n", "\t\tif false then\n"),
    ("start: nothing pending in the save", R, "\tc.Pend = { Id = id, Plus = -1, Gold = r.Gold, Mats = table.clone(r.Mats), Bound = next(bound) ~= nil and bound or nil, Bless = bless }\n", ""),
    # A23-206 / A23-213 bound materials (10/16): crafts use them, results are free, a refund gives them back bound
    ("bound: a craft result is bound", R, "{ { Id = r.Item, N = n } }, nil, \"Craft\")", "{ { Id = r.Item, N = n, Bound = true } }, nil, \"Craft\")"),
    ("bound: a refund comes back free", R, "N = math.min(99, left), Bound = part[2] or nil })", "N = math.min(99, left) })"),
    ("bound: crafts take the free ones first", "LOOT_SOURCE", "\tif freeOnly then\n\t\tBOUND.Set(data, id, math.min(before, math.floor(num(data.Items[id]))))\n\telse",
     "\tif true then\n\t\tBOUND.Set(data, id, math.min(before, math.floor(num(data.Items[id]))))\n\telse"),
    ("bound: Pend.Bound never noted", R, "\t\telseif b > 0 then\n\t\t\tbound[item] = b\n", "\t\telseif false then\n"),
    ("bound: the save drops Pend.Bound", C, "Bound = next(bound) ~= nil and bound or nil,\n\t\t\tBless", "Bound = nil,\n\t\t\tBless"),
    ("bound: GrantItems ignores row.Bound", "LOOT_SOURCE", "addItem(player, data, id, n, false, row.Bound == true)", "addItem(player, data, id, n)"),
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
    ("xp: any side gets craft XP (A23-139)", R, "\tif roleOf(data) == r.Role then\n\t\tfame = Config.CraftFame(r, plus)", "\tif true then\n\t\tfame = Config.CraftFame(r, plus)"),
    ("end: one level at most", R, "\twhile rr.Lv < K().MaxLv do\n", "\tif rr.Lv < K().MaxLv then\n"),
    ("end: no Crafted signal", R, "\tCraftService.Crafted:Fire(player, recipeId, plus)\n", ""),
    ("end: no CraftInfo after", R, "\t\tsendInfo(player, data)\n\tend\n\tif r.Kind == \"Gear\"", "\tend\n\tif r.Kind == \"Gear\""),
    ("end: leave loses the craft", R, "\t\tcloseAtZero(player, \"Leave\")\n", ""),
    ("end: KO loses the craft", R, "\t\t\tcloseAtZero(player, \"KO\")\n", ""),
    ("end: a stopped craft never finishes", R, "if type(data.Craft) == \"table\" and type(data.Craft.Pend) == \"table\" and CraftService.Settle(player, data) == \"wait\" then", "if false then"),
    ("end: an unknown Pend stays", R, "\tif type(K().Recipes[p.Id]) ~= \"table\" then\n\t\tc.Pend = nil\n", "\tif type(K().Recipes[p.Id]) ~= \"table\" then\n"),
    # --- remotes
    ("refund: no gold back", R, "\t\tif gold > 0 then pcall(S.ProgressionService.AddBankGold, player, gold, \"CraftRefund\") end\n", ""),
    ("refund: no materials back", R, "\t\tif #list > 0 then pcall(S.LootService.GrantItems, player, list, nil, \"CraftRefund\") end\n", ""),
    ("refund: rows over 99", R, "{ Id = item, N = math.min(99, left), Bound", "{ Id = item, N = left, Bound"),
    ("refund: a doubled source", R, "pcall(S.ProgressionService.AddBankGold, player, gold, \"CraftRefund\")", "pcall(S.ProgressionService.AddBankGold, player, gold, \"Monster\")"),
    ("pend: the earned +N forgotten", R, "\tif type(c.Pend) == \"table\" and c.Pend.Id == recipeId then c.Pend.Plus = plus end\n", ""),
    ("pend: a waiting craft always +0", R, "return complete(player, data, p.Id, math.max(0, math.floor(num(p.Plus))), misses(), 0) and \"done\" or \"wait\"", "return complete(player, data, p.Id, 0, misses(), 0) and \"done\" or \"wait\""),
    ("off: the join writes when off", R, "\t\tif type(data) ~= \"table\" or not on() then return end\n", "\t\tif type(data) ~= \"table\" then return end\n"),
    ("item: a part of it given", R, "\tif before + n > Config.Loot.ItemCap then return false end -- never a part of it\n", ""),
    ("gear: no caps at the end", R, "\t\tif sum >= ST.GearSum or math.floor(num(own[key])) >= Config.SaveV4.OwnKeyMax then return false end\n", ""),
    ("gear: only the sum at the end", R, "\t\tif sum >= ST.GearSum or math.floor(num(own[key])) >= Config.SaveV4.OwnKeyMax then return false end\n", "\t\tif sum >= ST.GearSum then return false end\n"),
    ("finish limit: any id uses it", R, "\tif not sess or sess.Id ~= sid then return end -- a stale / wrong id never uses up the limit of the real Finish\n", ""),
    ("info: no On list", R, "\t\tOn = onIds, Rep = ", "\t\tOn = nil, Rep = "),
    ("info: On lists every recipe", R, "\t\tif r.Role == role and CraftService.RecipeOn(id) then table.insert(onIds, id) end\n", "\t\tif r.Role == role then table.insert(onIds, id) end\n"),
    ("start: a switched-off recipe says nothing", R, "\t\tif type(id) == \"string\" and type(K().Recipes[id]) == \"table\" then notify(player, \"NotReady\") end\n", ""),
    ("start: an unknown id says NotReady", R, "\t\tif type(id) == \"string\" and type(K().Recipes[id]) == \"table\" then notify(player, \"NotReady\") end\n", "\t\tnotify(player, \"NotReady\")\n"),
    ("bench: no prompts", R, "\tfor _, part in CollectionService:GetTagged(K().StationTag) do pcall(addPrompt, part) end\n\tCollectionService:GetInstanceAddedSignal(K().StationTag):Connect(guard(\"station\", addPrompt))\n", ""),
    ("bench: two prompts", R, " or part:FindFirstChild(\"CraftPrompt\") then return end\n", " then return end\n"),
    ("bench: any role", R, "\tif type(role) ~= \"string\" or type(K().Text.Stations[role]) ~= \"string\" then return end\n", "\tif type(role) ~= \"string\" then return end\n"),
    ("bench: anyone opens the window", R, "\tif roleOf(data) ~= role then\n\t\tnotify(player, \"NotArtisan\")\n", "\tif false then\n\t\tnotify(player, \"NotArtisan\")\n"),
    ("bench: no window", R, "\tfire(player, \"OpenPanel\", \"Craft\")\n", ""),
    ("bench: when off too", R, "\tif not on() or typeof(part) ~= \"Instance\"", "\tif typeof(part) ~= \"Instance\""),
    # --- ⑤ the tamer's recipes (summon S1 = Kind Pet, Pet Treats T1)
    ("config: S1 at research stage 1", C, "Species = \"BabySlime\", Family = \"Slime\", Research = 150,", "Species = \"BabySlime\", Family = \"Slime\", Research = 50,"),
    ("config: T1 makes two", C, "Item = \"PetTreat\", N = 3,", "Item = \"PetTreat\", N = 2,"),
    ("config: treats from petals (hunting only)", C, "Item = \"PetTreat\", N = 3, Lv = 1, Gold = 10, Mats = { Herb = 3 },", "Item = \"PetTreat\", N = 3, Lv = 1, Gold = 10, Mats = { Petal = 3 },"),
    ("config: Pet Treats sold at the Forge", C, "Icon = \"IconPetTreat\", Source = \"Craft\",", "Icon = \"IconPetTreat\","),
    ("pet: on without the research switch", R, "\t\tif not (Config.FeatureOn(\"Research\") and type(r.Species) == \"string\"", "\t\tif not (type(r.Species) == \"string\""),
    ("pet: on without PetService", R, "\t\t\tand P and type(P.SummonPet) == \"function\"\n\t\t\tand type(P.HasRoom) == \"function\" and T", "\t\t\tand T"),
    ("pet: no research check", R, "\tif r.Kind == \"Pet\" then\n\t\tlocal ok, pts = pcall(S.TamerService.Points, player, r.Family)\n\t\tif not ok or num(pts) < num(r.Research) then\n", "\tif false then\n\t\tlocal ok, pts = pcall(S.TamerService.Points, player, r.Family)\n\t\tif not ok or num(pts) < num(r.Research) then\n"),
    ("pet: one point short is enough", R, "\t\tif not ok or num(pts) < num(r.Research) then\n", "\t\tif not ok or num(pts) + 1 < num(r.Research) then\n"),
    ("pet: no room check", R, "\t\tlocal ok, yes = pcall(S.PetService.HasRoom, player)\n\t\treturn ok and yes == true\n", "\t\treturn true\n"),
    ("pet: the hammer adds nothing", R, "\n\t\t\t\t+ math.max(0, math.floor(num(plus))))\n", ")\n"),
    ("pet: no top of 10", R, "\t\t\tspd = math.min(Config.SaveV4.PetRollSpd[2], ", "\t\t\tspd = math.min(math.huge, "),
    ("pet: random 5..10 before the hammer", R, "ST.Rng:NextInteger(lo, math.max(lo, math.floor(num(r.Spd[2], lo))))", "ST.Rng:NextInteger(lo, 10)"),
    ("pet: a failed summon counts as made", R, "\t\tif not ok or type(uid) ~= \"string\" then return false end\n\t\tlocal okS", "\t\tif not ok then return false end\n\t\tlocal okS"),
    ("pet: Sum not counted", R, "\t\tlocal okS, err = pcall(S.TamerService.AddSummon, player, r.Family)\n", "\t\tlocal okS, err = true, nil\n"),
    ("pet: no Pet in the result", R, "LvUp = up, Pet = pet, Fame = fame,", "LvUp = up, Fame = fame,"),
    # --- ⑦ fame and rank
    ("config: rank 2 at 50", C, "\t{ Id = \"Journeyman\", Rep = 30 },", "\t{ Id = \"Journeyman\", Rep = 50 },"),
    ("config: the perfect bonus at any +N", C, "\tif n > 0 and plus == 2 then n += F.PerfectBonus end\n", "\tif n > 0 and plus >= 1 then n += F.PerfectBonus end\n"),
    ("config: every recipe in the lowest band", C, "\t\t\tn = band.N\n\t\t\tbreak\n", "\t\t\tn = band.N\n"),
    ("config: a rank one point late", C, "\t\tif rep >= row.Rep then rank = i end\n", "\t\tif rep > row.Rep then rank = i end\n"),
    ("fame: none", R, "\t\tfame = Config.CraftFame(r, plus) -- ⑦ (never the 2x XP pass)\n", ""),
    ("fame: anyone earns it", R, "\tlocal xp, fame = 0, 0\n\tif roleOf(data) == r.Role then\n\t\tfame = Config.CraftFame(r, plus) -- ⑦ (never the 2x XP pass)\n", "\tlocal xp, fame = 0, Config.CraftFame(r, plus)\n\tif roleOf(data) == r.Role then\n"),
    ("fame: no lifetime Rep", R, "\t\tc.Rep = math.min(Config.SaveV4.MaxCount, math.floor(num(c.Rep)) + fame)\n", ""),
    ("fame: no cap", R, "\t\tc.Rep = math.min(Config.SaveV4.MaxCount, math.floor(num(c.Rep)) + fame)\n", "\t\tc.Rep = math.floor(num(c.Rep)) + fame\n"),
    ("fame: not on the weekly board", R, "\t\t\tlocal okR, errR = pcall(RS.Credit, player, \"Artisan\", fame, \"Craft\")\n", "\t\t\tlocal okR, errR = true, nil\n"),
    ("rank: no line", R, "\t\tlocal okN, errN = pcall(Net.NotifyKey, player, \"Config.Craft.Text.RankUp\", { { Key = \"Config.Craft.Text.Ranks.\" .. row.Id } }, \"reward\")\n", "\t\tlocal okN, errN = true, nil\n"),
    ("rank: no signal", R, "\t\tCraftService.RankUp:Fire(player, rank1)\n", ""),
    ("rank: a line every craft", R, "\tif rank1 > rank0 and player.Parent == Players then\n", "\tif rank1 >= rank0 and player.Parent == Players then\n"),
    ("rank: the attribute for everyone", R, "\tlocal okA, errA = pcall(function() player:SetAttribute(\"ArtisanRank\", role and rank or 0) end)\n", "\tlocal okA, errA = pcall(function() player:SetAttribute(\"ArtisanRank\", rank) end)\n"),
    ("rank: no attribute", R, "\tlocal okA, errA = pcall(function() player:SetAttribute(\"ArtisanRank\", role and rank or 0) end)\n", "\tlocal okA, errA = true, nil\n"),
    ("rank: a faction change not followed", R, "\tfor _, pair in { { \"ClassService\", \"ClassChanged\" }, { \"FactionService\", \"FactionChanged\" } } do\n", "\tfor _, pair in { { \"ClassService\", \"ClassChanged\" } } do\n"),
    ("info: no Rep / Rank", R, "\t\tOn = onIds, Rep = math.floor(num(c.Rep)), Rank = rank, NextRep = nextRep, Tool = toolOf(c, role) })\n", "\t\tOn = onIds, Tool = toolOf(c, role) })\n"),
    ("result: no Fame", R, "Pet = pet, Fame = fame,", "Pet = pet,"),
    ("remote: extra arguments taken", R, "\tif select(\"#\", ...) ~= 1 then return end\n\tlocal id = ...\n", "\tlocal id = ...\n"),
    ("remote: no start rate limit", R, "\tif not Util.RateLimit(player, \"CraftStart\", num(Config.RateLimits.CraftStart, 3)) then return end\n", ""),
    ("remote: a two-argument Finish taken", R, "\tif select(\"#\", ...) ~= 1 then return end\n\tlocal sid = ...\n", "\tlocal sid = ...\n"),
    ("remote: a text strike id taken", R, "\tlocal sid, i, ms = ...\n\tif type(sid) ~= \"number\" then return end\n", "\tlocal sid, i, ms = ...\n\tsid = tonumber(sid) or sid\n"),
    # 최종 검수 10/15: the craft goal row (CraftService.NextGoal)
    ("goal: a made recipe again", R, "r.Role == role and num(made[id]) <= 0 and lv >= num(r.Lv, 1)", "r.Role == role and lv >= num(r.Lv, 1)"),
    ("goal: any role's recipe", R, "if r and r.Role == role and num(made[id])", "if r and num(made[id])"),
    ("goal: gold ignored", R, " and gold >= num(r.Gold) and hasMats(data, r) then", " and hasMats(data, r) then"),
    ("goal: materials ignored", R, " and gold >= num(r.Gold) and hasMats(data, r) then", " and gold >= num(r.Gold) then"),
    ("goal: research ignored", R, "\t\t\t\tready = ok and num(pts) >= num(r.Research)\n", ""),
    ("goal: the switch ignored", R, "\tif not on() or type(data) ~= \"table\" then return nil end\n\tlocal role = roleOf(data)\n\tif not role then return nil end\n\tlocal c = type(data.Craft)",
     "\tif type(data) ~= \"table\" then return nil end\n\tlocal role = roleOf(data)\n\tif not role then return nil end\n\tlocal c = type(data.Craft)"),
    ("goal: the hook missing", C, "\t\t\t{ Kind = \"Craft\", Service = \"CraftService\", Feature = \"Crafting\" },\n", ""),
    ("goal: the line says the role, not the station", R, "return string.format(T.Goal, station), \"Craft\"", "return string.format(T.Goal, role), \"Craft\""),
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
