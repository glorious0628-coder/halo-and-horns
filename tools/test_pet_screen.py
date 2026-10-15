"""Pet roster screens (SPEC A23-194, 개발 2 server dev2-pets12 merged 10/15), offline static check.

The craft window lists no pet recipe whose species has no model yet (Config.PetReady false - the server's CraftInfo.On
leaves it out too); the pet window shows a pet's own bonus (Config.PetBonus at its level, a % with one decimal) for
every Bonus type but Speed (its own lines) and None (an emote pet), with words for each type in
Config.ClientText.PetWindow.Bonus; the following pet's bonus line dims in a PvP zone (PetService uses 0 there) and the
window redraws when ZonePvP changes. Each mutation must make a check fail.

Usage: py tools/test_pet_screen.py
"""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"CRAFT": SPS / "CraftWindow.luau", "PET": SPS / "PetWindow.luau",
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau"}


def statics(s: dict) -> list[tuple[str, bool]]:
    craft, pet, cfg = s["CRAFT"], s["PET"], s["CONFIG"]
    species = cfg[cfg.find("Species = {", cfg.find("Config.Pets = {")):]
    species = species[:species.find("\n\t},\n")]
    kinds = set(re.findall(r'Bonus = \{ Type = "(\w+)"', species))
    words = cfg[cfg.find("Config.ClientText.PetWindow = {"):]
    words = words[:words.find("\n}\n")]
    bonus = re.search(r"Bonus = \{([^}]*)\}", words)
    keys = set(re.findall(r"(\w+) = \"", bonus.group(1))) if bonus else set()
    return [
        ("craft: a pet recipe without its model is not listed",
         'local hidden = r.Kind == "Pet" and type(Config.PetReady) == "function" and Config.PetReady(r.Species) ~= true' in craft
         and "and onList(info, id) and not hidden then" in craft),
        ("pet window: the bonus from Config.PetBonus at the pet's level, Speed / None skipped",
         'if type(kind) ~= "string" or kind == "Speed" or kind == "None" or type(Config.PetBonus) ~= "function" then return nil end' in pet
         and "local v = tonumber(Config.PetBonus(sp, lv, kind)) or 0" in pet),
        ("a % with one decimal", "Pct = math.floor(v * 1000 + 0.5) / 10" in pet),
        ("both row kinds carry the bonus", pet.count("Bonus = PetWindow.BonusOf(sp, lv)") == 2),
        ("the row draws the bonus words", 'if type(words) == "string" then line ..= " · " .. string.format(words, string.format("%g", row.Bonus.Pct)) end' in pet),
        ("PvP zone: the following pet's bonus line dims", 'if row.Equipped and row.Bonus and LocalPlayer and LocalPlayer:GetAttribute("ZonePvP") == true then' in pet
         and "lineLabel.TextTransparency = 0.55" in pet),
        ("the window redraws on ZonePvP", "Faction = true, ZonePvP = true }" in pet),
        ("words for every bonus type a species has (not Speed / None)",
         bool(kinds) and (kinds - {"Speed", "None"}) <= keys, f"{sorted(kinds)} vs {sorted(keys)}"),
    ]


MUTATIONS = [
    ("CRAFT", "unready pets listed", "and onList(info, id) and not hidden then", "and onList(info, id) then"),
    ("PET", "Speed twice", 'kind == "Speed" or kind == "None" or', 'kind == "None" or'),
    ("PET", "whole % only", "Pct = math.floor(v * 1000 + 0.5) / 10", "Pct = math.floor(v * 100 + 0.5)"),
    ("PET", "the following pet without its bonus", "Roll = roll, CanFollow = false, CanPutAway = false, Icon = (speciesDef(sp) or {}).Icon or T.DefaultIcon,\n\t\t\t\tBonus = PetWindow.BonusOf(sp, lv) })",
     "Roll = roll, CanFollow = false, CanPutAway = false, Icon = (speciesDef(sp) or {}).Icon or T.DefaultIcon })"),
    ("PET", "no dim in PvP", "\t\tlineLabel.TextTransparency = 0.55\n", ""),
    ("PET", "ZonePvP not watched", "Faction = true, ZonePvP = true }", "Faction = true }"),
    ("CONFIG", "a type without words", 'KillXP = "XP from hunts +%s%%",', ""),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    src = {k: p.read_text(encoding="utf-8") for k, p in FILES.items()}
    st = statics(src)
    for item in st:
        print(("STATIC_OK " if item[1] else "STATIC_FAIL ") + item[0] + ("" if item[1] or len(item) < 3 else " :: " + item[2]))
    good = all(item[1] for item in st)
    caught = 0
    for key, name, old, new in MUTATIONS:
        if src[key].count(old) != 1:
            print(f"MUTATION NOT_APPLIED {name} (matched {src[key].count(old)})")
            continue
        m = dict(src)
        m[key] = src[key].replace(old, new)
        bad = not all(item[1] for item in statics(m))
        caught += 1 if bad else 0
        print(("MUTATION caught  " if bad else "MUTATION MISSED ") + name)
    passed = good and caught == len(MUTATIONS)
    print(f"Status: {'passed' if passed else 'failed'} (statics {sum(1 for i in st if i[1])}/{len(st)}, mutations {caught}/{len(MUTATIONS)})")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
