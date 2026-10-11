"""The two new fields and their seven monster kinds (Coral Coast, Crystal Cave Woods; SPEC A23-119 / A23-123), offline.

게임성 개발 2, 2026-10-11 (docs/design/new_zones_monsters_2026-10-11.md). The new zones and kinds are Config data with
Season = "NewZones", switched by Config.NewZones.Enabled (false as shipped) and added to Config.ZoneOrder by
Config.NewZonesApply only while it is on. Runs the CURRENT Config (and its real helpers SeasonOn / MonsterActive /
EffectiveMonsterCounts / MonsterTargets / ZoneAt / MonsterLevel / QuestKind / NewZonesApply) on tools/fixtures/dev2_kit.luau +
tools/fixtures/new_zones_offline.luau with the installed official Luau CLI, next to Config.luau as it was at the base commit
BASE (read with `git show`, never written) for the "nothing that existed changed" comparison: ZoneAt over a grid of points on
every existing zone rect, every existing zone / kind / loot table / bark / level. No Studio, network, DataStore or Roblox API
calls; mutations run on in-memory copies of Config.luau only.

Usage: py tools/test_new_zones.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-11/offline_dev2_new_zones_2026-10-11.json
"""
from __future__ import annotations

import subprocess

from dev2_offline import ROOT, SHARED, Suite, run

# the last Config.luau before the new zones (origin/main 048127fa9e, 2026-10-11). Re-pin it only when an EXISTING zone, kind or
# loot row changes on purpose after this round (the comparison then reads the new numbers as the base)
BASE = "048127fa9e"
FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
}
C = "CONFIG_SOURCE"
_BASE_CACHE: dict[str, str] = {}


def base_source(rel: str) -> str:
    if rel not in _BASE_CACHE:
        proc = subprocess.run(["git", "show", f"{BASE}:{rel}"], cwd=ROOT, capture_output=True, timeout=60)
        if proc.returncode != 0:
            raise ValueError(f"git show {BASE}:{rel} failed; the 'nothing that existed changed' baseline is missing")
        _BASE_CACHE[rel] = proc.stdout.decode("utf-8-sig").replace("\r\n", "\n")
    return _BASE_CACHE[rel]


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return {"CONFIG_SOURCE": sources[C], "UTIL_SOURCE": sources["UTIL_SOURCE"],
            "BASE_CONFIG_SOURCE": base_source("src/ReplicatedStorage/Shared/Config.luau")}


MUTATIONS = [
    # the switch and the zones
    ("the switch is on as shipped", C, "\tEnabled = false,\n\tZoneIds = { \"CoralCoast\", \"CrystalWoods\" },",
     "\tEnabled = true,\n\tZoneIds = { \"CoralCoast\", \"CrystalWoods\" },"),
    ("a zone without its season", C,
     "MinLevel = 1, PvP = false, Town = false, Faction = nil, Season = \"NewZones\",\n\t\tFloorColor = Color3.fromRGB(235, 215, 160)",
     "MinLevel = 1, PvP = false, Town = false, Faction = nil,\n\t\tFloorColor = Color3.fromRGB(235, 215, 160)"),
    ("a zone put into ZoneOrder unconditionally", C, "\t\"SkeletonRuins\" }\nConfig.Zones = {", "\t\"SkeletonRuins\", \"CoralCoast\" }\nConfig.Zones = {"),
    ("NewZonesApply appends twice", C, "table.find(Config.ZoneOrder, id) == nil then", "true then"),
    ("NewZonesApply ignores the switch", C, "\tif not Config.SeasonOn(\"NewZones\") then return false end\n", ""),
    ("a placeholder rect moved onto the meadow", C,
     "CoralCoast = { Id = \"CoralCoast\", Name = \"Coral Coast\", Center = Vector3.new(2300, 0, 300),",
     "CoralCoast = { Id = \"CoralCoast\", Name = \"Coral Coast\", Center = Vector3.new(430, 0, 0),"),
    ("a placeholder rect inside the map bounds", C,
     "CrystalWoods = { Id = \"CrystalWoods\", Name = \"Crystal Cave Woods\", Center = Vector3.new(2300, 0, -300),",
     "CrystalWoods = { Id = \"CrystalWoods\", Name = \"Crystal Cave Woods\", Center = Vector3.new(1800, 0, -300),"),
    ("the new zone has a level gate", C,
     "MinLevel = 1, PvP = false, Town = false, Faction = nil, Season = \"NewZones\",\n\t\tFloorColor = Color3.fromRGB(90, 150, 140)",
     "MinLevel = 12, PvP = false, Town = false, Faction = nil, Season = \"NewZones\",\n\t\tFloorColor = Color3.fromRGB(90, 150, 140)"),
    # an existing thing changed
    ("an existing kind changed (Goblin HP)", C, "Zone = \"GoblinWoods\", Count = 7, HP = 90,", "Zone = \"GoblinWoods\", Count = 7, HP = 95,"),
    ("an existing loot row changed (Brute horn)", C, "{ Item = \"BruteHorn\", P = 0.5 },", "{ Item = \"BruteHorn\", P = 0.9 },"),
    ("an existing bark changed (Goblin)", C, "Spot = { \"Heh!\", \"Mine!\", \"Ooh, shiny!\" },", "Spot = { \"Heh!\", \"Mine!\", \"Ooh, shiny?\" },"),
    # monsters
    ("a kind without Season", C, "Zone = \"CoralCoast\", Count = 8, Season = \"NewZones\",", "Zone = \"CoralCoast\", Count = 8,"),
    ("a slime shape", C, "Speed = 14, Shape = \"Humanoid\", Scale = 0.8,", "Speed = 14, Shape = \"Slime\", Scale = 0.8,"),
    ("a slime model", C, "ModelFrom = \"LittleGhost\", Float = 1.5 },", "ModelFrom = \"Slime\", Float = 1.5 },"),
    ("the golem is a boss", C, "Zone = \"CrystalWoods\", Count = 2, Season = \"NewZones\",", "Zone = \"CrystalWoods\", Count = 2, Boss = true, Season = \"NewZones\","),
    ("a ranged kind", C, "ModelFrom = \"Goblin\", AnimFrom = \"Goblin\" },\n\tJellyfish", "ModelFrom = \"Goblin\", AnimFrom = \"Goblin\", Ranged = { Range = 20 } },\n\tJellyfish"),
    ("the golem is small", C, "Speed = 8, Shape = \"Humanoid\", Scale = 1.9,", "Speed = 8, Shape = \"Humanoid\", Scale = 1.5,"),
    ("too many golems", C, "Zone = \"CrystalWoods\", Count = 2, Season = \"NewZones\",", "Zone = \"CrystalWoods\", Count = 4, Season = \"NewZones\","),
    ("the jellyfish stops floating", C, "ModelFrom = \"LittleGhost\", Float = 1.5 },", "ModelFrom = \"LittleGhost\" },"),
    ("a model from a kind that does not exist", C, "ModelFrom = \"LittleGhost\", Float = 2 },", "ModelFrom = \"LittleGhosts\", Float = 2 },"),
    ("the mushroom takes goblin slots", C, "Zone = \"CrystalWoods\", Count = 4, Season = \"NewZones\",",
     "Zone = \"CrystalWoods\", Count = 4, Takes = { Goblin = 2 }, Season = \"NewZones\","),
    ("the hermit crab hits harder than the brute", C, "HP = 120, Damage = 7, XP = 36", "HP = 120, Damage = 13, XP = 36"),
    ("the crab tougher than the goblin", C, "HP = 60, Damage = 4, XP = 20, Gold = 11,", "HP = 160, Damage = 4, XP = 20, Gold = 11,"),
    ("the lizard's XP below the goblin", C, "Count = 9, Season = \"NewZones\",\n\t\tHP = 95, Damage = 6, XP = 30,", "Count = 9, Season = \"NewZones\",\n\t\tHP = 95, Damage = 6, XP = 20,"),
    ("the golem's XP above the knight", C, "HP = 480, Damage = 15, XP = 110, Gold = 75,", "HP = 480, Damage = 15, XP = 210, Gold = 75,"),
    ("the golem's gold is zero", C, "HP = 480, Damage = 15, XP = 110, Gold = 75,", "HP = 480, Damage = 15, XP = 110, Gold = 0,"),
    ("stats fall inside a field (bat tougher than mushroom)", C, "HP = 110, Damage = 7, XP = 34, Gold = 19,", "HP = 210, Damage = 7, XP = 34, Gold = 19,"),
    ("a kind without its own level", C, "\tCoralCrab = 8, Jellyfish = 9, HermitCrab = 11,\n", "\tJellyfish = 9, HermitCrab = 11,\n"),
    ("levels not rising (jellyfish below the crab)", C, "CoralCrab = 8, Jellyfish = 9,", "CoralCrab = 9, Jellyfish = 8,"),
    ("a kind twice in MonsterTypeOrder", C, "\"CoralCrab\", \"Jellyfish\", \"HermitCrab\", \"Goblin\",", "\"CoralCrab\", \"Jellyfish\", \"HermitCrab\", \"Jellyfish\", \"Goblin\","),
    ("a kind missing in MonsterTypeOrder", C, "\"CrystalLizard\", \"CaveBat\", \"GlowMushroom\", \"CrystalGolem\", \"Skeleton\",", "\"CrystalLizard\", \"CaveBat\", \"CrystalGolem\", \"Skeleton\","),
    ("HermitCrab QuestAs typo", C, "QuestAs = \"CoralCrab\",", "QuestAs = \"CoralCrabb\","),
    # loot
    ("a loot item id typo", C, "{ Item = \"SeaShell\", P = 0.5, N = 2 },", "{ Item = \"SeaShel\", P = 0.5, N = 2 },"),
    ("a loot chance above 1", C, "{ Item = \"CrystalShard\", P = 0.6, N = 2 },", "{ Item = \"CrystalShard\", P = 1.6, N = 2 },"),
    ("a loot chance of 0", C, "{ Item = \"CrystalShard\", P = 0.4 },", "{ Item = \"CrystalShard\", P = 0, N = 1 },"),
    ("a scroll chance above the neighbour (crab Enh70)", C,
     "{ Item = \"SeaShell\", P = 0.35 },\n\t\t\t{ Item = \"Enh70\", P = 0.01 },", "{ Item = \"SeaShell\", P = 0.35 },\n\t\t\t{ Item = \"Enh70\", P = 0.02 },"),
    ("a transfer chance above the neighbour (hermit Move70)", C, "{ Item = \"Move70\", P = 0.01 }, { Item = \"Move30\", P = 0.003 }, { Item = \"Move10\", P = 0.0007 },\n\t\t\t{ Potion = \"HP\", P = 0.03 }, { Potion = \"MP\", P = 0.03 },\n\t\t},\n\t\tCrystalLizard",
     "{ Item = \"Move70\", P = 0.06 }, { Item = \"Move30\", P = 0.003 }, { Item = \"Move10\", P = 0.0007 },\n\t\t\t{ Potion = \"HP\", P = 0.03 }, { Potion = \"MP\", P = 0.03 },\n\t\t},\n\t\tCrystalLizard"),
    ("a potion chance above the neighbour (jellyfish)", C, "{ Item = \"Move10\", P = 0.0002 },\n\t\t\t{ Potion = \"HP\", P = 0.015 }, { Potion = \"MP\", P = 0.015 },\n\t\t},\n\t\tHermitCrab",
     "{ Item = \"Move10\", P = 0.0002 },\n\t\t\t{ Potion = \"HP\", P = 0.15 }, { Potion = \"MP\", P = 0.015 },\n\t\t},\n\t\tHermitCrab"),
    ("a weapon row on the mushroom", C, "{ Item = \"Move10\", P = 0.0005 },\n\t\t\t{ Potion = \"HP\", P = 0.03 }, { Potion = \"MP\", P = 0.03 },\n\t\t},\n\t\tCrystalGolem",
     "{ Item = \"Move10\", P = 0.0005 },\n\t\t\t{ Potion = \"HP\", P = 0.03 }, { Potion = \"MP\", P = 0.03 }, { Weapon = 4, P = 0.001 },\n\t\t},\n\t\tCrystalGolem"),
    ("the golem drops a tier 5 weapon", C, "{ Weapon = 4, P = 0.003 },", "{ Weapon = 5, P = 0.003 },"),
    ("the golem's weapon chance above the brute's", C, "{ Weapon = 4, P = 0.003 },", "{ Weapon = 4, P = 0.03 },"),
    ("a material sells for nothing", C, "Name = \"Sea Shell\", Sell = 4,", "Name = \"Sea Shell\", Sell = 0,"),
    ("a material not in the item order", C, "\"SlimeCore\", \"SeaShell\", \"GoblinTooth\",", "\"SlimeCore\", \"GoblinTooth\","),
    ("a material is not a Material", C, "CrystalShard = { Kind = \"Material\",", "CrystalShard = { Kind = \"Junk\","),
    ("the crab drops the other field's material", C, "{ Item = \"SeaShell\", P = 0.35 },", "{ Item = \"CrystalShard\", P = 0.35 },"),
    ("a new loot table is missing (bat)", C, "\t\tCaveBat = {\n\t\t\t{ Item = \"CrystalShard\", P = 0.3 },", "\t\tCaveBatX = {\n\t\t\t{ Item = \"CrystalShard\", P = 0.3 },"),
    # barks
    ("a missing bark line", C, "Low = { \"Sidestep!\" },", "Low = {},"),
    ("a bark line that is not a string", C, "Idle = { \"Rumble~\", \"Big yawn.\" },", "Idle = { \"Rumble~\", 7 },"),
    ("a bark line too long", C, "Spot = { \"Bloop-bloop!\", \"Wiggle!\" },", "Spot = { \"Bloop-bloop! Bloop-bloop! Bloop!\", \"Wiggle!\" },"),
    ("a bark line shared with another kind", C, "Spot = { \"Snip snip!\", \"Pinch time!\" },", "Spot = { \"Heh!\", \"Pinch time!\" },"),
    ("no bubble family", C, "\t\tCoralCrab = \"Coral\", Jellyfish = \"Coral\", HermitCrab = \"Coral\" },", "\t\tJellyfish = \"Coral\", HermitCrab = \"Coral\" },"),
    ("a family without bubble art key", C, "Crystal = \"BarkBubbleCrystalLizard\", Coral = \"BarkBubbleCoralCrab\" },", "Coral = \"BarkBubbleCoralCrab\" },"),
    # text
    ("Korean in a name", C, "CoralCrab = { Name = \"Coral Crab\", Short = \"Coral Crab\",", "CoralCrab = { Name = \"산호 게\", Short = \"Coral Crab\","),
    ("a heart in a bark line", C, "Spot = { \"Pop-pop!\", \"Spore-y?\" },", "Spot = { \"Pop-pop!\", \"Spore-y♥\" },"),
    ("an accent in an item name", C, "Name = \"Crystal Shard\", Sell = 8,", "Name = \"Crystal Shard\\u{e9}\", Sell = 8,"),
]


SUITE = Suite(
    mark="NEWZONES",
    fixture=ROOT / "tools/fixtures/new_zones_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-11/offline_dev2_new_zones_2026-10-11.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=lambda: (0, []),
    contract="A23-119 / A23-123 new fields: Config.NewZones.Enabled is false as shipped; with it off the two zones (Coral Coast, "
             "Crystal Cave Woods, placeholder rects east of Config.Map.Bounds) are out of Config.ZoneOrder, the seven kinds "
             "(Season NewZones) are inactive with spawn count / target 0, and ZoneAt over every existing zone rect, every existing "
             "zone, kind, loot table, bark and level equal the base commit " + BASE + "; with it on Config.NewZonesApply appends the "
             "zones once (twice adds nothing), their centres resolve to them, the kinds get their Count, no existing point changes "
             "zone and no existing kind changes count. Kinds: no slime shape / model, no boss, no ranged; positive numbers; stats rise "
             "with MonsterLevel inside a field; HP / Damage / XP / Gold lie between the level neighbours on the plain ladder (Slime Lv2, "
             "Goblin Lv12, Skeleton Lv26; Scale < 1.2) or the big ladder (Slime Prince Lv5, Goblin Brute Lv18, Skeleton Knight Lv30; "
             "Scale >= 1.2), equal allowed; Float on Jellyfish / Cave Bat; golem Scale >= 1.8 and Count <= 3. Loot: every item "
             "exists, P in (0, 1], the field's material (Material, Sell > 0, in Config.Loot.Order), scroll / transfer / potion / "
             "weapon chances at most the Goblin's (plain) or Goblin Brute's (big), a weapon row (tier <= 4) only on the golem. Barks: "
             "4 moments with short lines (<= 24 chars; A23-74 <= 2 words and 12 letters, not shared with another kind), a bubble family. "
             "MonsterTypeOrder once each, QuestAs resolves, English-only text (printable ASCII, the ellipsis and ~).",
    limitations="Config data only: the spawn code (MonsterService), the maps / panels that read Config.ZoneOrder and the client bubbles "
                "are not run here (they are covered by test_map_v2, test_monster_bark and the season suites). The zone rects are "
                "placeholders: the real land, the 3D models, bubble art, item icons, minimap and music are not made yet.",
)

if __name__ == "__main__":
    run(SUITE)
