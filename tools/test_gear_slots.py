"""Gear slots (GearService + the hooks, 게임성 개발 3, 2026-10-12), offline.

Contract docs/design/gear_slots_2026-10-12.md (A23-133; 게임성 검수 10/12: numbers OK, wear Lv 10 / 20 / 30, PvP: the ring
multiplies the attacker's weapon damage before the SAME 0.8..1.5 clamp, the armor raises the victim's real MaxHealth while
the PvP base stays the BASE MaxHealth; GearAtk / GearHp in JusticeService POWER.Watch; ONE CONDITION: a gear's +N is only the
hammer's +0..+2, scrolls never touch gear). Armor (max HP x 1 + 6 / 12 / 18% + 2% a +N) and Ring (my hits and power x 1 + 4 /
8 / 12% + 1% a +N) for the player; PetArmor (pet XP + 20 / 40 / 60% + 10% a +N, floored) and PetAcc (walk bonus + 1 / 2 / 3% +
0.5% a +N, Speed.Cap stays) for the pet that follows; EquipGear(slot, key) / EquipPetGear(uid, slot, key): key = "T:P" of
an Own thing or "" (take off), one-place rule, Own caps 60 / 20, wear level, my pet only, ready + alive, 0.5 s, exact
argument count; GearInfo { Own, On, Pet } + the attributes GearAtk / GearHp at PlayerReady and after changes; switched by
Config.Features.Gear (off). Runs the CURRENT Config, Util, GearService, PetService, CombatService (the two hits),
LootService (UseItem) and the extracts of PlayerService (computeMaxHealth, ComputeWalkSpeed) and JusticeService (POWER.Watch) on
tools/fixtures/dev2_kit.luau + tools/fixtures/dev3_world.luau with tools/fixtures/gear_slots_offline.luau and the installed
official Luau CLI. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources.

Usage: py tools/test_gear_slots.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-12/offline_dev3_gear_slots_2026-10-12.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "GEAR_SOURCE": SSS / "GearService.luau",
    "PET_SOURCE": SSS / "PetService.luau",
    "COMBAT_SOURCE": SSS / "CombatService.luau",
    "LOOT_SOURCE": SSS / "LootService.luau",
    "PLAYER_SOURCE": SSS / "PlayerService.luau",
    "JUSTICE_SOURCE": SSS / "JusticeService.luau",
}
C, G, PE, CO, L, P, J = ("CONFIG_SOURCE", "GEAR_SOURCE", "PET_SOURCE", "COMBAT_SOURCE", "LOOT_SOURCE", "PLAYER_SOURCE",
                         "JUSTICE_SOURCE")
HOOK = " -- ⑥ gear (게임성 개발 3)"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    player, justice = sources[P], sources[J]
    return {
        "CONFIG_SOURCE": sources[C],
        "UTIL_SOURCE": sources["UTIL_SOURCE"],
        "GEAR_SOURCE": sources[G],
        "PET_SOURCE": sources[PE],
        "COMBAT_SOURCE": sources[CO],
        "LOOT_SOURCE": sources[L],
        "MAXHP_SOURCE": ("local Config, stat, healthMult = ...\n" + function_block(player, "local function gearHp(") + "\n"
                         + function_block(player, "local function computeMaxHealth(") + "\nreturn computeMaxHealth\n"),
        "SPEED_SOURCE": ("local PlayerService, S, Config, Util, classDef = ...\n"
                         + function_block(player, "function PlayerService.ComputeWalkSpeed(") + "\nreturn PlayerService\n"),
        "WATCH_SOURCE": "local POWER = ...\n" + function_block(justice, "function POWER.Watch(") + "\nreturn POWER\n",
    }


MUTATIONS = [
    # A23-219 ② crafted options (게임성 개발 2)
    ('opt: GearParse ignores the option', C, '\tif Config.GearKey(t, p, o) ~= key then return nil end\n\treturn t, p, o', '\tif Config.GearKey(t, p, o) ~= key then return nil end\n\treturn t, p, 0'),
    ('opt: the weapon option outside GearMultsOf', C, '\tlocal w = 1 + Config.CraftOptBonus("Weapon", okO and o or nil)\n', '\tlocal w = 1\n'),
    ('opt: PetXP without the acc option', C, '\t\treturn Config.GearBonusOf("PetArmor", row.PetArmor) + Config.CraftOptBonus("PetAcc", o)', '\t\treturn Config.GearBonusOf("PetArmor", row.PetArmor)'),
    ('opt: pet XP by the armor only', PE, '\tlocal exact = n * (1 + petGear(data, uid, "PetXP")) + (rems and rems[uid] or 0)', '\tlocal exact = n * (1 + petGear(data, uid, "PetArmor")) + (rems and rems[uid] or 0)'),
    ("⑤: Gear back on reads nobody", "GEAR_SOURCE", "\t\t\tif k ~= \"Gear\" or value ~= true then return end\n", "\t\t\tdo return end\n"),
    # --- the table (Config)
    ("config: on by default", C, "Config.Features.Gear = false\nConfig.Gear = {", "Config.Features.Gear = true\nConfig.Gear = {"),
    ("config: Armor T1 +7%", C, "Base = { 0.06, 0.12, 0.18 }, Step = 0.02,", "Base = { 0.07, 0.12, 0.18 }, Step = 0.02,"),
    ("config: Armor +N 3%", C, "Step = 0.02, Wear", "Step = 0.03, Wear"),
    ("config: Ring T3 +13%", C, "Base = { 0.04, 0.08, 0.12 }", "Base = { 0.04, 0.08, 0.13 }"),
    ("config: Ring +N 2%", C, "Step = 0.01, Wear", "Step = 0.02, Wear"),
    ("config: PetArmor T1 +25%", C, "Base = { 0.20, 0.40, 0.60 }", "Base = { 0.25, 0.40, 0.60 }"),
    ("config: PetArmor +N 15%", C, "Step = 0.10, Wear", "Step = 0.15, Wear"),
    ("config: PetAcc T2 +3%", C, "Base = { 0.01, 0.02, 0.03 }", "Base = { 0.01, 0.03, 0.03 }"),
    ("config: PetAcc +N 1%", C, "Step = 0.005, Wear", "Step = 0.01, Wear"),
    ("config: Armor wears at Lv5", C, "Step = 0.02, Wear = { 10, 20, 30 }", "Step = 0.02, Wear = { 5, 20, 30 }"),
    ("config: Ring T3 wears at Lv20", C, "Step = 0.01, Wear = { 10, 20, 30 }", "Step = 0.01, Wear = { 10, 20, 20 }"),
    ("config: a plus up to +10 (a scroll's)", C, "\tMaxPlus = 2,\n\tOwnSum = 60,", "\tMaxPlus = 10,\n\tOwnSum = 60,"),
    ("config: 80 things in Own", C, "\tOwnSum = 60,", "\tOwnSum = 80,"),
    ("config: PetAccMax 5%", C, "\tPetAccMax = 0.04,", "\tPetAccMax = 0.05,"),
    ("config: equip every 0.1 s", C, "Config.RateLimits.EquipGear = 0.5\n", "Config.RateLimits.EquipGear = 0.1\n"),
    ("config: GearMult lets a loss through", C, "or v == math.huge or v < 1 then return 1 end", "or v == math.huge then return 1 end"),
    ("config: GearMultsOf ignores the switch", C, "\tif not Config.FeatureOn(\"Gear\") then return w, 1 end\n\tlocal ok, a, h", "\tlocal ok, a, h"),
    ("config: GearMultsOf swaps the two", C, "return Config.GearMult(a) * w, Config.GearMult(h)", "return Config.GearMult(h) * w, Config.GearMult(a)"),
    ("config: GearBonus without the plus cap", C, "or plus < 0 or plus > Config.Gear.MaxPlus then return 0 end", "or plus < 0 then return 0 end"),
    ("config: GearBonus without the tier cap", C, "if tier < 1 or tier > Config.Gear.MaxTier or plus", "if tier < 1 or plus"),
    ("config: GearBonus takes fractions", C, " or tier ~= math.floor(tier) or plus ~= math.floor(plus) then return 0 end", " then return 0 end"),
    ("config: GearParse keeps leading zeros", C, "\tif Config.GearKey(t, p, o) ~= key then return nil end\n\treturn t, p, o", "\treturn t, p, o"),
    ("config: GearParse plus up to the scroll's +10", C, "or p > Config.Gear.MaxPlus then return nil end", "or p > Config.Loot.MaxEnhance then return nil end"),
    ("config: PetGearBonus ignores the switch", C, "\tif not Config.FeatureOn(\"Gear\") or type(gear) ~= \"table\"", "\tif type(gear) ~= \"table\""),
    ("config: the save repair keeps plus up to +10", C, "\tGearMaxPlus = 2,", "\tGearMaxPlus = 10,"),
    ("config: the plus cap of the repair is the scroll's", C, "or p > Config.SaveV4.GearMaxPlus then return nil end", "or p > Config.Loot.MaxEnhance then return nil end"),
    # --- the power number
    ("power: CombatPower drops the gear", C, "\tlocal raw = Config.PowerOf(level, tier, 1, enhance, alloc, gear)\n", "\tlocal raw = Config.PowerOf(level, tier, 1, enhance, alloc)\n"),
    ("power: PowerOf ignores the gear", C, "\tif type(gear) == \"table\" then am, hm = am * Config.GearMult(gear.A), hm * Config.GearMult(gear.H) end" + HOOK + "\n", ""),
    ("power: the armor in the attack factor", C, "hm * Config.GearMult(gear.H)", "hm * Config.GearMult(gear.A)"),
    ("power: CombatPowerOf drops the gear", C, "tier, enhance, alloc, { A = gearAtk, H = gearHp })", "tier, enhance, alloc)"),
    ("power: MaxCombatPower without the best gear", C, "Config.Loot.MaxEnhance, even, top))", "Config.Loot.MaxEnhance, even))"),
    ("power: MaxCombatPower shares one cache", C, "\tif gearOn then key ..= \"Gear\" end -- ⑥ gear (게임성 개발 3): its own cache value\n", ""),
    ("power: MaxCombatPower without the best armor", C, "H = 1 + Config.GearBonus(\"Armor\", Config.Gear.MaxTier, Config.Gear.MaxPlus) }", "H = 1 }"),
    # --- the walk speed
    ("walk: PetAcc never added", C, "\t\tpet += math.min(petAcc, Config.Gear.PetAccMax) -- ⑥ gear (게임성 개발 3)\n", ""),
    ("walk: PetAcc not cut", C, "pet += math.min(petAcc, Config.Gear.PetAccMax)", "pet += petAcc"),
    ("walk: PetAcc without a pet", C, "if kaiju ~= true and pet > 0 and type(petAcc)", "if kaiju ~= true and type(petAcc)"),
    ("walk: PetAcc for a kaiju", C, "if kaiju ~= true and pet > 0 and type(petAcc)", "if type(petAcc)"),
    ("walk: PetAcc with the switch off", C, "and petAcc > 0 and Config.FeatureOn(\"Gear\") then", "and petAcc > 0 then"),
    ("walk: ComputeWalkSpeed drops PetAcc", P, ", player:GetAttribute(\"PetAcc\")) -- ⑥ gear", ") -- ⑥ gear"),
    # --- the hooks (게임성 개발 2's files)
    ("hook: max HP without the armor", P, "\t\t* gearHp(player))) -- ⑥ gear", "\t\t* 1)) -- ⑥ gear"),
    ("hook: max HP from the ring's number", P, "\tlocal ok, _, h = pcall(Config.GearMultsOf, player)\n", "\tlocal ok, h = pcall(Config.GearMultsOf, player)\n"),
    ("hook: monster hit without the ring", CO, "\t\t* gearAtk(attacker) -- ⑥ gear (게임성 개발 3): the ring's atk mult\n", ""),
    # (2-A ⑧: the stat mults aAtk / vHp sit beside the rings in the same ratio)
    ("hook: PvP ratio without the attacker's ring", CO, " * gearAtk(attacker) * aAtk\n", " * aAtk\n"),
    ("hook: PvP ratio without the victim's ring", CO, "/ (vWeapon * gearAtk(victim) * vHp)", "/ (vWeapon * vHp)"),
    ("hook: PvP ratio from the armor", CO, " * gearAtk(attacker) * aAtk\n", " * select(2, Config.GearMultsOf(attacker)) * aAtk\n"),
    ("hook: PvP ratio without the clamp", CO, "\tratio = math.clamp(ratio, floor, Config.PvP.PowerRatioMax)\n", "\tratio = math.max(ratio, floor)\n"),
    ("hook: PvP base grows with the victim's armor", CO, "vAlloc.H) * Config.PvP.HitPctOfMaxHP\n", "vAlloc.H) * Config.PvP.HitPctOfMaxHP * select(2, Config.GearMultsOf(victim))\n"),
    ("hook: the power watch misses GearAtk", J, "\"StatHp\", \"GearAtk\", \"GearHp\", \"WeaponOpt\" } do", "\"StatHp\", \"GearHp\", \"WeaponOpt\" } do"),
    ("hook: the power watch misses GearHp", J, "\"StatHp\", \"GearAtk\", \"GearHp\", \"WeaponOpt\" } do", "\"StatHp\", \"GearAtk\", \"WeaponOpt\" } do"),
    ("hook: the power watch misses WeaponOpt (A23-219 ②)", J, "\"StatHp\", \"GearAtk\", \"GearHp\", \"WeaponOpt\" } do", "\"StatHp\", \"GearAtk\", \"GearHp\" } do"),
    # --- PetService (the pet's side)
    ("pet: publish sets no PetAcc", PE, "\tplayer:SetAttribute(\"PetAcc\", acc > 0 and acc or nil)\n", ""),
    ("pet: PetAcc from the armor", PE, "\tlocal acc = petGear(data, uid, \"PetAcc\")\n", "\tlocal acc = petGear(data, uid, \"PetArmor\")\n"),
    # 10/16 (GPT artisan_switch_r1 ③): A23-194's bonus attributes now sit between PetAcc and the speed refresh
    ("pet: PetAcc after the speed refresh", PE,
     "\tplayer:SetAttribute(\"PetAcc\", acc > 0 and acc or nil)\n\t-- A23-194: the following pet's bonus kind and size (nil = none / a look-only pet; the walk speed stays PetLv / PetRoll).\n\t-- The value is the pet's own: the server uses 0 in a PvP zone or the Crown Pit (PetService.Bonus; ZonePvP tells the UI)\n\tlocal def = p and PETS.Species[p.Sp] or nil\n\tlocal kind = type(def) == \"table\" and type(def.Bonus) == \"table\" and def.Bonus.Type or nil\n\tlocal size = (kind and kind ~= \"None\") and Config.PetBonus(p.Sp, p.Lv, kind, p.Roll and p.Roll.Spd) or 0\n\tplayer:SetAttribute(\"PetBonusType\", (kind and kind ~= \"None\") and kind or nil)\n\tplayer:SetAttribute(\"PetBonus\", size > 0 and size or nil)\n\trefreshSpeed(player)\n",
     "\t-- A23-194: the following pet's bonus kind and size (nil = none / a look-only pet; the walk speed stays PetLv / PetRoll).\n\t-- The value is the pet's own: the server uses 0 in a PvP zone or the Crown Pit (PetService.Bonus; ZonePvP tells the UI)\n\tlocal def = p and PETS.Species[p.Sp] or nil\n\tlocal kind = type(def) == \"table\" and type(def.Bonus) == \"table\" and def.Bonus.Type or nil\n\tlocal size = (kind and kind ~= \"None\") and Config.PetBonus(p.Sp, p.Lv, kind, p.Roll and p.Roll.Spd) or 0\n\tplayer:SetAttribute(\"PetBonusType\", (kind and kind ~= \"None\") and kind or nil)\n\tplayer:SetAttribute(\"PetBonus\", size > 0 and size or nil)\n\trefreshSpeed(player)\n\tplayer:SetAttribute(\"PetAcc\", acc > 0 and acc or nil)\n"),
    ("pet: no XP bonus", PE, "\tlocal exact = n * (1 + petGear(data, uid, \"PetXP\")) + (rems and rems[uid] or 0)\n", "\tlocal exact = n + (rems and rems[uid] or 0)\n"),
    ("pet: the XP bonus not floored", PE, "\tlocal whole = math.floor(exact + 1e-9) -- (1e-9: 20 x 1.2 is 24, not 23.999..)\n", "\tlocal whole = exact\n"),
    ("pet: the XP bonus from the accessory", PE, "uid, \"PetXP\")) + (rems and rems[uid] or 0)", "uid, \"PetAcc\")) + (rems and rems[uid] or 0)"),
    ("pet: a kill without the bonus", PE, "giveXP(p, gearXP(player, data, uid, math.max(0, math.floor(num((Config.Pets or {}).XPPerKill, 1)))))", "giveXP(p, math.max(0, math.floor(num((Config.Pets or {}).XPPerKill, 1))))"),
    ("pet: AddPetXP without the bonus", PE, "\tn = gearXP(player, data, uid, n) -- ⑥ gear (게임성 개발 3): PetArmor of this pet\n", ""),
    ("pet: Refresh never republishes", PE, "\tpublish(player, data)\n\treturn true\nend", "\treturn true\nend"),
    # --- GearService: the rules
    ("equip: the switch not checked", G, "\tif not on() then return nil, \"off\" end\n", ""),
    ("equip: not-ready players wear", G, "if not data or not S.PlayerService.IsReady(player) or not Util.IsAlive(player) then return nil, \"state\" end", "if not data or not Util.IsAlive(player) then return nil, \"state\" end"),
    ("equip: KO'd players wear", G, "if not data or not S.PlayerService.IsReady(player) or not Util.IsAlive(player) then return nil, \"state\" end", "if not data or not S.PlayerService.IsReady(player) then return nil, \"state\" end"),
    ("equip: any caller", G, "if typeof(player) ~= \"Instance\" or not player:IsA(\"Player\") or player.Parent ~= Players then return nil, \"state\" end", "if player.Parent ~= Players then return nil, \"state\" end"),
    ("equip: any slot name", G, "if type(slot) ~= \"string\" or Config.Gear.Slots[slot] == nil then return \"slot\" end", "if type(slot) ~= \"string\" then return \"slot\" end"),
    ("equip: any pet slot name", G, "if type(slot) ~= \"string\" or Config.Gear.PetSlots[slot] == nil then return \"slot\" end", "if type(slot) ~= \"string\" then return \"slot\" end"),
    ("equip: not my pet", G, "if not (type(P) == \"table\" and type(P.GetPet) == \"function\" and P.GetPet(player, uid)) then return \"pet\" end", "if false then return \"pet\" end"),
    ("equip: no ownership check", G, "if math.floor(num(own[kind])) < 1 then return \"notyours\", \"NotYours\" end", "if false then return \"notyours\", \"NotYours\" end"),
    ("equip: no wear level", G, "if math.floor(num(data.Level, 1)) < num(def.Wear[tier], 1) then return \"level\", \"NeedLevel\" end", "if false then return \"level\", \"NeedLevel\" end"),
    ("equip: the wear level one too high", G, "< num(def.Wear[tier], 1) then return \"level\"", "<= num(def.Wear[tier], 1) then return \"level\""),
    ("equip: the same key swaps with itself", G, "\tif current == key then return \"same\" end\n", ""),
    ("equip: the new one stays in Own", G, "\ttakeOwn(own, kind)\n\tif current ~= \"\" then", "\tif current ~= \"\" then"),
    ("equip: the old one is lost", G, "\t\taddOwn(own, oldKind)\n\tend\n\tworn[slot] = key\n", "\tend\n\tworn[slot] = key\n"),
    ("equip: a swap without room for the old one", G, "\t\tif not roomFor(own, oldKind) then\n\t\t\taddOwn(own, kind) -- undone: all of it or nothing\n\t\t\treturn \"full\", \"Full\"\n\t\tend\n", ""),
    ("equip: a refused swap loses the new one", G, "\t\t\taddOwn(own, kind) -- undone: all of it or nothing\n", "\t\t\tlocal _ = kind -- undone\n"),
    ("equip: a take-off without room", G, "\t\tif not roomFor(own, oldKind) then return \"full\", \"Full\" end\n\t\taddOwn(own, oldKind)\n\t\tworn[slot] = nil\n", "\t\taddOwn(own, oldKind)\n\t\tworn[slot] = nil\n"),
    ("equip: no per-key cap", G, "return ownSum(own) < Config.Gear.OwnSum and math.floor(num(own[kind])) < Config.SaveV4.OwnKeyMax", "return ownSum(own) < Config.Gear.OwnSum"),
    ("equip: no sum cap", G, "return ownSum(own) < Config.Gear.OwnSum and math.floor(num(own[kind])) < Config.SaveV4.OwnKeyMax", "return math.floor(num(own[kind])) < Config.SaveV4.OwnKeyMax"),
    ("equip: a take-off of nothing", G, "\t\tif current == \"\" then return \"none\" end\n", ""),
    ("equip: On loses its empty slot", G, "\tif result == \"ok\" then g.On[slot] = g.On[slot] or \"\" end -- On always has both slots (\"\" = empty)\n", ""),
    ("equip: a pet keeps an empty row", G, "if next(row) ~= nil then g.Pet[uid] = row else g.Pet[uid] = nil end", "g.Pet[uid] = row"),
    ("equip: a broken Gear table not repaired", G, "\tif type(g) ~= \"table\" or type(g.Own) ~= \"table\" or type(g.On) ~= \"table\" or type(g.Pet) ~= \"table\" then\n\t\tdata.Gear = Config.SanitizeGear(g)\n\tend\n", ""),
    # --- GearService: what the owner sees
    ("equip: no GearInfo after a change", G, "\t\tsendInfo(player, g)\n\t\tif petChanged then refreshPet(player) end\n", "\t\tif petChanged then refreshPet(player) end\n"),
    ("equip: the pet is not republished", G, "\t\tif petChanged then refreshPet(player) end\n", "\t\tlocal _ = petChanged\n"),
    ("equip: no notice", G, "\t\tnotify(player, noteKey, \"info\")\n", ""),
    ("equip: a refusal says nothing", G, "\t\tnotify(player, noteKey, \"bad\")\n", ""),
    ("equip: a refusal sends no GearInfo", G, "\t\tsendInfo(player, g) -- the window may already show the change: the truth again\n", ""),
    ("equip: no GearHp", G, "\tplayer:SetAttribute(\"GearHp\", hp)\n", ""),
    ("equip: no GearAtk", G, "\tplayer:SetAttribute(\"GearAtk\", atk)\n", ""),
    ("equip: the armor's HP not refreshed", G, "\tif before ~= hp and type(ps) == \"table\"", "\tif false and type(ps) == \"table\""),
    ("equip: the ring from the armor", G, "return 1 + wornBonus(\"Ring\", g.On.Ring, level), 1 + wornBonus(\"Armor\", g.On.Armor, level)", "return 1 + wornBonus(\"Armor\", g.On.Armor, level), 1 + wornBonus(\"Ring\", g.On.Ring, level)"),
    ("join: the switch not checked", G, "local function onReady(player)\n\tif not on() then return end\n", "local function onReady(player)\n"),
    ("join: no attributes", G, "\treturnOrphans(player, data, g)\n\tpublishAttrs(player, g, data)\n", "\treturnOrphans(player, data, g)\n"),
    ("join: no GearInfo", G, "\tpublishAttrs(player, g, data)\n\tsendInfo(player, g)\n\tif not LEVEL[player] then\n", "\tpublishAttrs(player, g, data)\n\tif not LEVEL[player] then\n"),
    ("join: a gone pet keeps its gear", G, "and not S.PetService.GetPet(player, uid) then", "and false then"),
    ("join: a gone pet's gear lost when Own is full", G, "\t\t\t\tif roomFor(g.Own, kind) then\n", "\t\t\t\tif true then\n"),
    ("join: an empty row stays", G, "\t\t\tif next(row) == nil then g.Pet[uid] = nil end\n", ""),
    # --- GearService: the remotes
    ("remote: extra arguments taken (EquipGear)", G, "\tif select(\"#\", ...) ~= 2 then return end\n", ""),
    ("remote: extra arguments taken (EquipPetGear)", G, "\tif select(\"#\", ...) ~= 3 then return end\n", ""),
    ("remote: no rate limit (EquipGear)", G, "\tif not Util.RateLimit(player, \"EquipGear\", num(Config.RateLimits.EquipGear, 0.5)) then return end\n", ""),
    ("remote: no rate limit (EquipPetGear)", G, "\tif not Util.RateLimit(player, \"EquipPetGear\", num(Config.RateLimits.EquipGear, 0.5)) then return end\n", ""),
    # --- a scroll never reaches gear
    ("scroll: UseItem takes a gear key as a tier", L, "\treturn type(tier) == \"number\" and tier == tier and tier == math.floor(tier) and tier >= 1 and tier <= Config.MaxWeaponTier\n",
     "\treturn type(tier) == \"string\" or (type(tier) == \"number\" and tier == tier and tier == math.floor(tier) and tier >= 1 and tier <= Config.MaxWeaponTier)\n"),
    # --- 게임성 개발 2 follow-ups (10/12)
    ("combat: armor in a fight", G, "\tif type(key) ~= \"string\" then return \"key\" end\n\tif fighting(player) then\n", "\tif type(key) ~= \"string\" then return \"key\" end\n\tif false then\n"),
    ("combat: pet gear in a fight", G, "\tif not (type(P) == \"table\" and type(P.GetPet) == \"function\" and P.GetPet(player, uid)) then return \"pet\" end\n\tif fighting(player) then\n", "\tif not (type(P) == \"table\" and type(P.GetPet) == \"function\" and P.GetPet(player, uid)) then return \"pet\" end\n\tif false then\n"),
    ("combat: a failing check blocks", G, "\treturn ok and yes == true\nend\n", "\treturn not ok or yes == true\nend\n"),
    ("pet xp: fractions dropped", PE, "\t\trems[uid] = rest\n", ""),
    ("pet xp: fractions never cleared", PE, "\telseif rems then\n\t\trems[uid] = nil\n\tend\n\treturn whole\n", "\tend\n\treturn whole\n"),
    ("hook: max HP calls Config directly", P, "\t\t* gearHp(player))) -- ⑥ gear", "\t\t* select(2, Config.GearMultsOf(player)))) -- ⑥ gear"),
    # --- 게임성 검수 10/12 (before the switch goes on)
    ("level: a level drop keeps the bonus", G, "\tif not tier or not def or level < num(def.Wear[tier], 1) then return 0 end\n", "\tif not tier or not def then return 0 end\n"),
    ("level: no Level watch", G, "\t\tLEVEL[player] = player:GetAttributeChangedSignal(\"Level\"):Connect(function()\n", "\t\tLEVEL[player] = player:GetAttributeChangedSignal(\"NoSuchAttr\"):Connect(function()\n"),
    ("info: no SendInfo", G, "\tsendInfo(player, gearOf(data))\n\treturn true\n", "\treturn true\n"),
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
    check("GearService" in ni and ni.index("GearService") > ni.index("PetService"), "Main INIT_ORDER has GearService after PetService")
    check("GearService" in ns and ns.index("GearService") > ns.index("PetService") and ns.index("GearService") < ns.index("PlayerService"),
          "Main START_ORDER has GearService after PetService and before PlayerService")
    check((SSS / "GearService.luau").is_file(), "the GearService module exists (the lists never name a missing module)")
    net = read(SHARED / "Net.luau")
    names = re.search(r"Net\.Names = \{(.*?)\n\}", net, re.S)
    nm = strip_comments(names.group(1)) if names else ""
    check(all(f'"{n}"' in nm for n in ("EquipGear", "EquipPetGear", "GearInfo")), "Net.Names has EquipGear, EquipPetGear and GearInfo")
    gear = strip_comments(read(SSS / "GearService.luau"))
    check("Net.Notify(" not in gear and "Net.NotifyKey" in gear, "GearService sends notices by key only (Net.NotifyKey)")
    check(not re.search(r"MarketplaceService|PromptPurchase|Robux|ProcessReceipt", gear), "no purchase path in GearService (stats are never sold)")
    check(not re.search(r"Enhance|Loot\.|WeaponTier|Scroll|MaxEnhance", gear), "GearService never touches scrolls, +N of weapons or the loot tables (a gear's +N is the hammer's only)")
    check(not re.search(r"\bplus\s*=|\bPlus\b", gear), "GearService never writes a plus (it only moves the keys it was given)")
    check("Gear" not in strip_comments(read(SSS / "LootService.luau")), "LootService (UseItem, the scrolls) never names gear")
    check(not re.search(r"Gear", strip_comments(read(SSS / "MonetizationService.luau"))), "no Robux path touches gear (MonetizationService)")
    config = read(SHARED / "Config.luau")
    check(config.count("Config.Features = { NeutralFaction = false, Market = false, StatPoints = false }\n") == 1,
          "the Config.Features = { ... } line is as it was")
    check(len(re.findall(r"^Config\.Features\.Gear = false$", config, re.M)) == 1, "Config.Features.Gear = false on its own line, once")
    gblock = config[config.index("Config.Gear = {"):config.index("-- the slot row of a player slot")]
    check(not re.search(r"Loot\.MaxEnhance|Enhance", gblock), "Config.Gear never mentions the scrolls' +N")
    craft = read(SSS / "CraftService.luau")
    check(re.search(r"GearSum = 60,", craft) is not None and "OwnSum = 60," in config, "CraftService.ST.GearSum and Config.Gear.OwnSum are both 60")
    # the one-line hooks in game dev 2's files
    player = strip_comments(read(SSS / "PlayerService.luau"))
    check("gearHp(player)" in function_block(player, "local function computeMaxHealth("), "PlayerService.computeMaxHealth: x the armor's hp mult")
    # 게임성 검수 10/12 (test_owner_restore runs a trimmed Config): every hook reads gear through a guarded helper
    # (type(Config.X) == "function" + pcall), never a bare Config.GearMultsOf( / Config.PetGearBonus( call
    pet_src = strip_comments(read(SSS / "PetService.luau"))
    for name, src, helper, fn in (("PlayerService", player, "local function gearHp(", "GearMultsOf"),
                                  ("CombatService", strip_comments(read(SSS / "CombatService.luau")), "local function gearAtk(", "GearMultsOf"),
                                  ("PetService", pet_src, "local function petGear(", "PetGearBonus")):
        block = function_block(src, helper)
        check(f'type(Config.{fn}) ~= "function"' in block and f"pcall(Config.{fn}," in block and f"Config.{fn}(" not in src,
              f"{name}: gear through a guarded helper only (no bare Config.{fn}( call)")
    check('player:GetAttribute("PetRoll"), player:GetAttribute("PetAcc"))' in function_block(player, "function PlayerService.ComputeWalkSpeed("),
          "PlayerService.ComputeWalkSpeed passes the PetAcc attribute")
    combat_raw = read(SSS / "CombatService.luau")
    combat = strip_comments(combat_raw)
    mh = function_block(combat, "function CombatService.ComputeMonsterHit(")
    pvp = function_block(combat, "function CombatService.ComputePvPHit(")
    check("gearAtk(attacker)" in mh, "CombatService.ComputeMonsterHit: x the ring's atk mult")
    justice = strip_comments(read(SSS / "JusticeService.luau"))
    gp = function_block(justice, "function JusticeService.GetPower(")
    gb = function_block(justice, "local function gearOf(")
    check("Config.StatAllocOf(player), gearOf(player))" in gp and 'type(Config.GearMultsOf) ~= "function"' in gb and "pcall(Config.GearMultsOf," in gb,
          "JusticeService.GetPower (the faction size) counts the gear (guarded)")
    craft = strip_comments(read(SSS / "CraftService.luau"))
    check('if r.Kind == "Gear" and S.GearService and type(S.GearService.SendInfo) == "function" then' in craft
          and "pcall(S.GearService.SendInfo, player)" in craft, "CraftService: a gear craft sends GearInfo (GearService.SendInfo)")
    # 게임성 개발 2: the Might Tonic (BuffService, on the dealt damage in damageMonster) and the ring (on the computed hit)
    # stack as a product: two separate factors on one path, neither replaces the other
    dmon = function_block(combat, "local function damageMonster(")
    check('dealt = dealt * S.BuffService.Mult(player, "MonsterDamage")' in dmon and "gearAtk" not in dmon
          and "BuffService" not in mh, "a Might Tonic x a ring: two factors (damageMonster x the tonic, ComputeMonsterHit x the ring)")
    check("gearAtk(attacker)" in pvp and "gearAtk(victim)" in pvp, "CombatService.ComputePvPHit: both rings inside the ratio")
    # A23-69 stage 2 (2-A ⑧): the victim's Health points raise the base (StatMaxHealth = MaxHealth while StatPoints is off);
    # the armor never does
    check(("local base = Config.MaxHealth(vLevel, faction(victim), vClass) * Config.PvP.HitPctOfMaxHP" in pvp
           or "local base = Config.StatMaxHealth(vLevel, faction(victim), vClass, vAlloc.H) * Config.PvP.HitPctOfMaxHP" in pvp)
          and "Gear" not in [line for line in pvp.splitlines() if "local base" in line][0],
          "ComputePvPHit: the base stays the victim's BASE MaxHealth (+ its Health points, never the armor)")
    check("ratio = math.clamp(ratio, floor, Config.PvP.PowerRatioMax)" in pvp, "ComputePvPHit: the same 0.8..1.5 clamp after the ratio")
    justice = read(SSS / "JusticeService.luau")
    watch = function_block(justice, "function POWER.Watch(")
    check('"GearAtk"' in watch and '"GearHp"' in watch, "JusticeService POWER.Watch follows GearAtk / GearHp")
    pet = read(SSS / "PetService.luau")
    publish = function_block(pet, "local function publish(")
    check('player:SetAttribute("PetAcc"' in publish and publish.index('player:SetAttribute("PetAcc"') < publish.index("refreshSpeed(player)"),
          "PetService.publish sets PetAcc before refreshSpeed")
    check("function PetService.Refresh(" in pet, "PetService.Refresh exists (GearService asks it to republish)")
    check(strip_comments(pet).count("gearXP(") == 3, "pet XP: the bonus has one function (defined once, called by a kill and by AddPetXP)")
    return count, failures


SUITE = Suite(
    mark="GEAR_SLOTS",
    fixture=ROOT / "tools/fixtures/gear_slots_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-12/offline_dev3_gear_slots_2026-10-12.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="Gear slots (docs/design/gear_slots_2026-10-12.md, 게임성 검수 10/12): Armor (max HP x 1 + 6/12/18% + 2% a +N, wear Lv "
             "10/20/30) and Ring (my hits and power x 1 + 4/8/12% + 1% a +N); PetArmor (pet XP + 20/40/60% + 10% a +N, floored) "
             "and PetAcc (walk bonus + 1/2/3% + 0.5% a +N, Speed.Cap stays) on the pet that follows; EquipGear(slot, key) / "
             "EquipPetGear(uid, slot, key) with key 'T:P' or '': one place (Own <-> On / Pet[uid]), Own 60 / 20 caps, wear "
             "level, my pet only, ready + alive, 0.5 s, exact argument count, keys-only notices; GearAtk / GearHp attributes "
             "and GearInfo { Own, On, Pet } at PlayerReady and after changes; hooks: computeMaxHealth, ComputeMonsterHit, "
             "ComputePvPHit (ring x weapon damage inside the same clamp, base = the victim's BASE MaxHealth), POWER.Watch, "
             "PetAcc in the walk speed, PetArmor in pet XP; Config.CombatPower / MaxCombatPower with the gear; Config.Features.Gear "
             "off = (1, 1) everywhere. A gear's +N is only the hammer's +0..+2: UseItem with a gear key changes nothing, "
             "Config.SanitizeGear keeps P in 0..2, GearService never writes a plus.",
    limitations="The gear window, the pet-gear row in the pet window and any Fx are client work (not in this job). Real "
                "Humanoid MaxHealth changes (RefreshCharacter) are a double here; PlayerService.computeMaxHealth, ComputeWalkSpeed and "
                "JusticeService POWER.Watch run as extracted functions with doubles. A kill gives a pet XPPerKill = 1: x1.2..x1.8 "
                "floors back to 1, so PetArmor shows on treats (+20 XP) and any bigger gain (a tuning note for 게임성 검수).",
)

if __name__ == "__main__":
    run(SUITE)
