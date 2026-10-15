"""A23-194 (최종 검수 10/15): the 12 beta pets on the server, offline.

Config.Pets.Species (12 rows: Name, Icon, Rarity, Family, Acquire, Bonus { Type, Min, Max }, Ready), Config.PetReady /
Config.PetBonus, Config.PetGrants + PetGrantBoss, Craft S2-S5; PetService.Bonus / BonusExtra (0 in a PvP zone, fractions
carried), the PetBonusType / PetBonus attributes, SummonPet without a roll for a no-roll species, and the sure gifts (goose
rounds, field boss kills by UserId, kaiju events, side quests, the join's quiet catch-up, never twice, never before Ready).
Runs the CURRENT Config, Util and PetService on tools/fixtures/dev2_kit.luau + dev3_world.luau with
tools/fixtures/pets12_offline.luau and the installed official Luau CLI. The hooks in ProgressionService (kill gold / XP),
VitalsService (HP potion) and LootService (material luck) are checked by source. No Studio, network or Roblox API calls.

Usage: py tools/test_pets12.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-15/offline_pets12_2026-10-15.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "PET_SOURCE": SSS / "PetService.luau",
}
C, PE = "CONFIG_SOURCE", "PET_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # the table
    ("a second species Ready", C, "Bonus = { Type = \"Potion\", Min = 0.01, Max = 0.03 }, Ready = false },",
     "Bonus = { Type = \"Potion\", Min = 0.01, Max = 0.03 }, Ready = true },"),
    ("ShowUnready on", C, "\tShowUnready = false,\n\tSpecies = {", "\tShowUnready = true,\n\tSpecies = {"),
    ("PetReady ignores Ready", C, "\treturn def.Ready ~= false or Config.Pets.ShowUnready == true", "\treturn true"),
    ("PetBonus: any kind", C, "\tif not b or b.Type ~= kind or kind == \"None\" then return 0 end", "\tif not b or kind == \"None\" then return 0 end"),
    ("PetBonus: Max at Lv1", C, "\treturn lo + (hi - lo) * (lv - 1) / math.max(1, P.MaxLv - 1)", "\treturn hi"),
    ("PetBonus: no level clamp", C, "\tlv = math.clamp(math.floor(lv), 1, P.MaxLv)\n\treturn lo + (hi - lo)", "\treturn lo + (hi - lo)"),
    ("a bigger gold cap", C, "Bonus = { Type = \"KillGold\", Min = 0.01, Max = 0.02 }, Ready = false },\n\t\tAcornGoblin",
     "Bonus = { Type = \"KillGold\", Min = 0.01, Max = 0.05 }, Ready = false },\n\t\tAcornGoblin"),
    ("goose needs 2", C, "Count = \"Goose\", Need = 3, Level = 5 },", "Count = \"Goose\", Need = 2, Level = 5 },"),
    # PetService
    ("Bonus ignores PvP", PE, "\tif type(p) ~= \"table\" or not Config.PetReady(p.Sp) or pvpNow(player) then return 0 end",
     "\tif type(p) ~= \"table\" or not Config.PetReady(p.Sp) then return 0 end"),
    ("Bonus ignores Ready", PE, "\tif type(p) ~= \"table\" or not Config.PetReady(p.Sp) or pvpNow(player) then return 0 end",
     "\tif type(p) ~= \"table\" or pvpNow(player) then return 0 end"),
    ("BonusExtra drops the fraction", PE, "\tlocal x = base * b + num(rem[kind])", "\tlocal x = base * b"),
    ("no bonus attributes", PE, "\tplayer:SetAttribute(\"PetBonus\", size > 0 and size or nil)\n", ""),
    ("a None pet shows a bonus type", PE, "\tplayer:SetAttribute(\"PetBonusType\", (kind and kind ~= \"None\") and kind or nil)",
     "\tplayer:SetAttribute(\"PetBonusType\", kind)"),
    ("no-roll summon of a speed species", PE, "\tif roll ~= nil or (type(def.Bonus) ~= \"table\" or def.Bonus.Type == \"Speed\") then",
     "\tif roll ~= nil then"),
    ("summon ignores Ready", PE, "\tif not data or not known(species) or not Config.PetReady(species) then return nil end\n\tlocal r = nil",
     "\tif not data or not known(species) then return nil end\n\tlocal r = nil"),
    ("gifts twice", PE, "or g.Got[row.Id] or not Config.PetReady(row.Species) then continue end",
     "or not Config.PetReady(row.Species) then continue end"),
    ("gifts before the level", PE, "\t\tif num(data.Level, 1) < num(row.Level, 1) or (type(row.Factions)", "\t\tif (type(row.Factions)"),
    ("gifts to any side", PE, " or (type(row.Factions) == \"table\" and not row.Factions[side]) then continue end", " then continue end"),
    ("one quest is enough", PE, "\t\t\t\tif st[q] ~= true then met = false end\n", ""),
    ("an owned pet is not got", PE, "\t\t\tif ownsSpecies(pets, row.Species) then\n\t\t\t\tg.Got[row.Id] = true",
     "\t\t\tif false then\n\t\t\t\tg.Got[row.Id] = true"),
    ("no join catch-up", PE, "\tlocal okG, errG = pcall(checkGrants, player, data) -- A23-194: a gift already earned\n", ""),
    ("junk tallies kept", PE, "type(v) == \"number\" and v == v and v >= 0 then n[k]", "true then n[k]"),
    ("a cancelled kaiju counts", PE, "\tif outcome ~= \"Defeated\" and outcome ~= \"Survived\" then return end\n\tlocal seen", "\tlocal seen"),
    ("a kaiju participant twice", PE, "\t\tif typeof(p) == \"Instance\" and not seen[p] then", "\t\tif typeof(p) == \"Instance\" then"),
    ("the kaiju itself not counted", PE, "\tlocal list = { kaiju }\n", "\tlocal list = {}\n"),
    ("no goose hook", PE, "\tconnectIf(\"GooseService\", \"GooseRewarded\"", "\tconnectIf(\"GooseService\", \"GooseRewardedX\""),
    ("no level-up check", PE, "\tconnectIf(\"ProgressionService\", \"LeveledUp\", onGrantCheck)\n", ""),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, name: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(name)

    prog = strip_comments(read(SSS / "ProgressionService.luau"))
    check('pcall(pet.BonusExtra, player, "KillGold", num(info.Gold))' in prog and 'M.AddCarriedGold(player, math.floor(eg), "Pet")' in prog
          and 'pcall(pet.BonusExtra, player, "KillXP", num(info.XP))' in prog and 'M.AddXP(player, math.floor(ex), cap, "Pet")' in prog,
          "ProgressionService: a kill adds the pet's KillGold / KillXP extra from the kill's base (source Pet)")
    cfg = strip_comments(read(SHARED / "Config.luau"))
    check("Pet = true" not in cfg.split("GoldSources = {", 1)[1].split("}", 1)[0], "source Pet is no PassBoost gold source (never x2)")
    vit = strip_comments(read(SSS / "VitalsService.luau"))
    check('pcall(pet.Bonus, player, "Potion")' in vit and "TUNE.HPRecovery * mult" in vit, "VitalsService: the HP potion x (1 + Potion bonus)")
    loot = strip_comments(read(SSS / "LootService.luau"))
    check('pcall(pet.Bonus, player, "MatLuck")' in loot and "info.MatMult = num(info.MatMult, 1) * (1 + math.min(luck, 0.05))" in loot,
          "LootService: the plain-material chance x (1 + MatLuck)")
    craft = strip_comments(read(SSS / "CraftService.luau"))
    check("Config.PetReady(r.Species)" in craft and "(r.Spd == nil or type(r.Spd) == \"table\")" in craft
          and "spd and { Spd = spd } or nil" in craft, "CraftService: a summon waits for its species (PetReady); no Spd = no roll")
    return count, failures


SUITE = Suite(
    mark="PETS12",
    fixture=ROOT / "tools/fixtures/pets12_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-15/offline_pets12_2026-10-15.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-194: 12 species, only the Baby Slime Ready (models later; ShowUnready for Studio checks). Bonus kinds Speed / Potion "
             "(+3%) / KillGold / KillXP (+2%) / MatLuck (x1.01) / None (Emote), Lv1 Min -> MaxLv Max, 0 in a PvP zone / the Crown "
             "Pit. Kill extras from the kill's base, source Pet (no pass x2), fractions carried. Gifts once each: goose 3 (Lv5), "
             "King Slime 5 (Lv8), Halo H2+H3+H6 / Horns R3+R5+R7 / guild N0b+N2+N4 (Lv10, own side), kaiju 3 (Lv15), Clatter 3 "
             "(Lv30); tallies in data.PetGrants (additive, Version unchanged); a join catches up, no line (A23-191); an owned species = got.",
    limitations="The pet window / follower / codex pages for the new species are game dev 1's (they wait for Ready). The kill / "
                "potion / loot hooks are checked by source here; their services' own suites keep passing.",
)

if __name__ == "__main__":
    run(SUITE)
