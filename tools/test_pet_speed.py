"""PET-1 the one walk speed, offline (design skills_weapons_pets_2026-10-05 §0-1, SPEC A23-15, A23-49 no skill buff).

Runs the CURRENT Config (Speed / Pets / PetSpeedBonus / WalkSpeed), PlayerService.ComputeWalkSpeed / RefreshSpeed /
applyStats, ZoneService.checkMove and the whole PetService on tools/fixtures/dev2_kit.luau with
tools/fixtures/pet_speed_offline.luau and the installed official Luau CLI. No Studio, network, DataStore or Roblox API
calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_pet_speed.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_dev2_pet_speed_2026-10-06.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "PLAYER_SOURCE": SSS / "PlayerService.luau",
    "ZONE_SOURCE": SSS / "ZoneService.luau",
    "PET_SOURCE": SSS / "PetService.luau",
}
C, P, Z, PET = "CONFIG_SOURCE", "PLAYER_SOURCE", "ZONE_SOURCE", "PET_SOURCE"


def block_after(text: str, start: str) -> str:
    """`start` up to and including the first line that is exactly '}' after it (a top-level table)."""
    first = text.find(start)
    last = text.find("\n}\n", first) if first >= 0 else -1
    if first < 0 or last < 0:
        raise ValueError(f"Source boundary changed: {start!r}; update the test extractor.")
    return text[first:last + 3]


def bindings(sources: dict[str, str]) -> dict[str, str]:
    player, zone = sources[P], sources[Z]
    return {
        "CONFIG_SOURCE": sources[C],
        "UTIL_SOURCE": sources["UTIL_SOURCE"],
        "SPEED_SOURCE": ("local PlayerService, S, Config, Util, classDef = ...\n"
                         + function_block(player, "function PlayerService.ComputeWalkSpeed(")
                         + function_block(player, "function PlayerService.RefreshSpeed(")
                         + "\nreturn PlayerService\n"),
        "APPLY_SOURCE": ("local PlayerService, computeMaxHealth = ...\n"
                         + function_block(player, "local function applyStats(") + "\nreturn applyStats\n"),
        "MOVE_SOURCE": ("local Config, Util = ...\nlocal AC = Config.AntiCheat or {}\n"
                        + block_after(zone, "local move = {")
                        + function_block(zone, "local function acNum(")
                        + function_block(zone, "local function checkMove(")
                        + "\nreturn checkMove, move\n"),
        "PET_SOURCE": sources[PET],
    }


MUTATIONS = [
    ("no cap", C, "\treturn math.min(raw, base * Config.Speed.Cap)\n", "\treturn raw\n"),
    ("cap 1.5", C, "Config.Speed = { Cap = 1.35 }", "Config.Speed = { Cap = 1.5 }"),
    ("Lv1 bonus 8%", C, "BabySlime = { Speed = { 0.07, 0.10 }", "BabySlime = { Speed = { 0.08, 0.10 }"),
    ("pet level not clamped", C, "\tlv = math.clamp(math.floor(lv), 1, P.MaxLv)\n", "\tlv = math.floor(lv)\n"),
    ("the pet bonus is never added", C, "local pet = kaiju == true and 0 or Config.PetSpeedBonus(petSpecies, petLv, petRoll)",
     "local pet = 0"),
    ("a kaiju keeps the pet bonus", C, "local pet = kaiju == true and 0 or Config.PetSpeedBonus(petSpecies, petLv, petRoll)",
     "local pet = Config.PetSpeedBonus(petSpecies, petLv, petRoll)"),
    # ⑤ a summoned pet's roll (게임성 개발 3, tamer_server §4)
    ("WalkSpeed drops the roll", C, "Config.PetSpeedBonus(petSpecies, petLv, petRoll)", "Config.PetSpeedBonus(petSpecies, petLv)"),
    ("RollGrow +5%", C, "\tRollGrow = 0.03,\n", "\tRollGrow = 0.05,\n"),
    ("the roll is not cut to its range", C, "\t\ta = math.clamp(roll, range[1], range[2]) / 100\n", "\t\ta = roll / 100\n"),
    ("a roll replaces the end only", C, "\t\ta = math.clamp(roll, range[1], range[2]) / 100\n\t\tb = a + P.RollGrow\n", "\t\tb = math.clamp(roll, range[1], range[2]) / 100 + P.RollGrow\n"),
    ("ComputeWalkSpeed ignores the roll", P, "kaiju,\n\t\tplayer:GetAttribute(\"PetRoll\"), player:GetAttribute(\"PetAcc\"))",
     "kaiju, nil, player:GetAttribute(\"PetAcc\"))"),
    ("publish sets no PetRoll", PET, "\tplayer:SetAttribute(\"PetRoll\", p and p.Roll and p.Roll.Spd or 0)\n", ""),
    ("class speed ignored", C, "local raw = base * (c.WalkSpeedMult or 1) * (1 + pet)", "local raw = base * (1 + pet)"),
    ("ComputeWalkSpeed reads no pet", P,
     'player:GetAttribute("EquippedPet"), player:GetAttribute("PetLv"), kaiju,', 'nil, 0, kaiju,'),
    ("kaiju state not read", P, 'kaiju = ok and st == "Active"', "kaiju = false"),
    ("the siren counts as the kaiju", P, 'kaiju = ok and st == "Active"', 'kaiju = ok and st ~= "None"'),
    ("RefreshSpeed also resets HP", P,
     "\tif humanoid and humanoid.Health > 0 then humanoid.WalkSpeed = PlayerService.ComputeWalkSpeed(player) end",
     "\tif humanoid and humanoid.Health > 0 then humanoid.WalkSpeed = PlayerService.ComputeWalkSpeed(player); "
     "humanoid.Health = humanoid.MaxHealth end"),
    ("RefreshSpeed on a dead humanoid", P,
     "\tif humanoid and humanoid.Health > 0 then humanoid.WalkSpeed", "\tif humanoid then humanoid.WalkSpeed"),
    ("applyStats keeps a speed of its own", P, "\thumanoid.WalkSpeed = PlayerService.ComputeWalkSpeed(player)\n",
     "\thumanoid.WalkSpeed = 20\n"),
    ("publish never refreshes the speed", PET, "\trefreshSpeed(player)\n", "\tlocal _ = refreshSpeed\n"),
    ("MoveMult 0.9 (checkMove too strict)", C, "\tMoveMult = 1.6,\n", "\tMoveMult = 0.9,\n"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    import re
    writes = []
    for path in sorted(SSS.glob("*.luau")):
        for line in read(path).splitlines():
            code = line.split("--", 1)[0]
            # monsters' own Humanoids (MonsterService: hum = the new monster, rec.Humanoid = a living monster record) are
            # not players
            if re.search(r"\.WalkSpeed\s*=[^=]", code) and "hum.WalkSpeed = def.Speed" not in code \
                    and "hum.WalkSpeed = 0" not in code and "humanoid.WalkSpeed, humanoid.JumpPower" not in code \
                    and not (path.name == "MonsterService.luau" and "rec.Humanoid.WalkSpeed" in code):
                writes.append(f"{path.name}: {line.strip()}")
    check(len(writes) == 2 and all("ComputeWalkSpeed(player)" in w for w in writes),
          "a player's WalkSpeed is written in exactly two places, both from ComputeWalkSpeed: " + " | ".join(writes))
    config = read(SHARED / "Config.luau")
    check("SpeedBuff" not in config and "SkillSpeed" not in config, "no skill speed buff (A23-49)")
    return count, failures


SUITE = Suite(
    mark="PET_SPEED",
    fixture=ROOT / "tools/fixtures/pet_speed_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-06/offline_dev2_pet_speed_2026-10-06.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="PET-1: Config.WalkSpeed(class, petSpecies, petLv, kaiju) = Config.Player.WalkSpeed x class WalkSpeedMult x "
             "(1 + Config.PetSpeedBonus(species, lv)), no skill buff (A23-49), at most Config.Speed.Cap (1.35) x the "
             "base. Baby slime +7% at pet Lv1 -> +10% at Lv10 (straight line, levels clamped 1..Config.Pets.MaxLv). An "
             "Active kaiju gets no pet bonus. PlayerService.ComputeWalkSpeed reads the class (classDef), EquippedPet / "
             "PetLv and KaijuService.GetState (pcall); applyStats (spawn / RefreshCharacter) and RefreshSpeed (WalkSpeed "
             "only, live humanoid) are the only player WalkSpeed writes; PetService publish calls RefreshSpeed. "
             "ZoneService.checkMove never flags any class x pet level x kaiju at its speed (dt 0.05-3 s) or the cap.",
    limitations="No zone / combat / grudge-sack speed rule exists today, so those states trigger no recompute (a later "
                "rule adds its trigger next to its input). Real character physics and network jitter are not modelled.",
)

if __name__ == "__main__":
    run(SUITE)
