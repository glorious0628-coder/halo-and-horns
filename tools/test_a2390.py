"""A23-90 (게임성 개발 2, 2026-10-09): the ruins' safe ring + Crown Pit PvP area, private-server rewards x0.5, offline.

Config.Zones.SkeletonRuins: PvP false, PvPArea "Crown Pit" (around the crown altar ruin, loot x1.25); Config.PvPAt /
PvPAreaAt / ZoneHasPvP; ZoneService's real applyZone (ZonePvP follows the position: crossing the pit's edge inside
the ruins changes it, with the entered-PvP / safe lines); Captain Clatter's fallback spot in the pit; the kill info's
AreaMult (MonsterService) multiplying LootService's drop rows. Config.PrivateServer: in a private server the real
ProgressionService.AddBankGold halves the goose ("Event"), war chest ("War") and bounty ("Bounty") gold before the
2x gold pass; the goose halves its XP. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory
copies of the sources only.

Usage: py tools/test_a2390.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-09/offline_dev2_a2390_2026-10-09.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "PROGRESSION_SOURCE": SSS / "ProgressionService.luau",
    "ZONE_SOURCE": SSS / "ZoneService.luau",
    "GOOSE_SOURCE": SSS / "GooseService.luau",
    "WAR_SOURCE": SSS / "WarService.luau",
    "PVP_SOURCE": SSS / "PvPService.luau",
    "MONSTER_SOURCE": SSS / "MonsterService.luau",
    "LOOT_SOURCE": SSS / "LootService.luau",
}
C, P, Z, G, M, L = "CONFIG_SOURCE", "PROGRESSION_SOURCE", "ZONE_SOURCE", "GOOSE_SOURCE", "MONSTER_SOURCE", "LOOT_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = {k: sources[k] for k in ("CONFIG_SOURCE", "UTIL_SOURCE", "PROGRESSION_SOURCE", "GOOSE_SOURCE", "WAR_SOURCE",
                                   "PVP_SOURCE")}
    out["APPLYZONE_EXTRACT"] = (
        "local Config, H = ...\n"
        "local zoneIds, pvpNow, notify, fmt, getFaction = H.zoneIds, H.pvpNow, H.notify, H.fmt, H.getFaction\n"
        "local ZoneService = H.ZoneService\n"
        "local pvpNoteAt, PVP_NOTE_GAP = H.pvpNoteAt, 20\n"
        "local DEFAULT_ZONE = \"Crossroads\"\n"
        + function_block(sources[Z], "local function applyZone(")
        + function_block(sources[Z], "function ZoneService.IsPvPZone(")
        + "\nreturn applyZone\n")
    # the loot / kill wiring as text the harness checks (MonsterService's AreaMult, LootService's row bonus)
    out["AREAMULT_TEXT"] = sources[M]
    out["ROWBONUS_TEXT"] = sources[L]
    return out


MUTATIONS = [
    ("the ruins all PvP again", C, "		MinLevel = 25, PvP = false, Town = false, Faction = nil,\n		PvPArea = { Name = \"Crown Pit\"",
     "		MinLevel = 25, PvP = true, Town = false, Faction = nil,\n		PvPArea = { Name = \"Crown Pit\""),
    ("no pit", C, "	return zone ~= nil and (zone.PvP == true or Config.PvPAreaAt(pos, zone) ~= nil)\n",
     "	return zone ~= nil and zone.PvP == true\n"),
    ("the pit is the whole ruins", C, "Center = Vector3.new(1660, 0, 0), Size = Vector3.new(200, 0, 240), LootMult = 1.25 },",
     "Center = Vector3.new(1520, 0, 0), Size = Vector3.new(520, 0, 580), LootMult = 1.25 },"),
    ("the pit test on X only", C, "	if math.abs(pos.X - a.Center.X) <= a.Size.X / 2 and math.abs(pos.Z - a.Center.Z) <= a.Size.Z / 2 then return a end\n",
     "	if math.abs(pos.X - a.Center.X) <= a.Size.X / 2 then return a end\n"),
    ("ZoneHasPvP ignores the pit", C, "	return type(zone) == \"table\" and (zone.PvP == true or type(zone.PvPArea) == \"table\")\n",
     "	return type(zone) == \"table\" and zone.PvP == true\n"),
    ("Clatter outside the pit", C, "Spawn = Vector3.new(1670, 0, 0), MinLevel = 25, War = 2,", "Spawn = Vector3.new(1300, 0, 0), MinLevel = 25, War = 2,"),
    ("zone PvP by zone only", Z, "	local pvp = Config.PvPAt(pos, zone)\n", "	local pvp = zone.PvP == true\n"),
    ("no change inside a zone", Z, "	if zone.Id == old and pvp == wasPvP then return end\n", "	if zone.Id == old then return end\n"),
    ("no PvP line", Z, "			notify(player, fmt(\"EnteredPvP\"), \"bad\", \"None\") -- happens to me: no Deny\n", ""),
    ("the safe line is back", Z, "\tend -- (leaving PvP: no line;", "\telseif not pvp and wasPvP then\n\t\tnotify(player, \"Safe zone.\", \"good\")\n\tend -- (leaving PvP: no line;"),
    ("the PvP line on every crossing", Z, "\tif pvp and not wasPvP and os.clock() - (pvpNoteAt[player] or -math.huge) >= PVP_NOTE_GAP then\n",
     "\tif pvp and not wasPvP then\n"),
    ("ZoneChanged inside a zone", Z, "	if zone.Id ~= old then ZoneService.ZoneChanged:Fire(player, zone.Id, old) end\n",
     "	ZoneService.ZoneChanged:Fire(player, zone.Id, old)\n"),
    ("ZonePvP not set", Z, "	player:SetAttribute(\"ZonePvP\", pvp)\n", ""),
    ("IsPvPZone by zone", Z, "	return pvpNow[player] == true\n", "	return ZoneService.GetZone(player).PvP == true\n"),
    # private servers
    ("never halved", P, "	if type(P) ~= \"table\" or game.PrivateServerId == \"\" then return 1 end\n", "	do return 1 end\n"),
    ("always halved", P, "	if type(P) ~= \"table\" or game.PrivateServerId == \"\" then return 1 end\n", "	if type(P) ~= \"table\" then return 1 end\n"),
    ("every source halved", P, "	if type(P) == \"table\" and type(P.HalfSources) == \"table\" and P.HalfSources[source] then\n",
     "	if type(P) == \"table\" then\n"),
    ("halved after the pass", P, "		amount = math.floor(amount * M.PrivateMult())\n		if amount <= 0 then return 0 end\n	end\n	amount = boostGold(player, amount, source)\n",
     "		amount = amount\n	end\n	amount = math.floor(boostGold(player, amount, source) * M.PrivateMult())\n"),
    ("goose XP full", G, "\txp = math.floor(xp * (prog and type(prog.PrivateMult) == \"function\" and tonumber(prog.PrivateMult()) or 1))\n", ""),
    ("a quarter", C, "	RewardMult = 0.5,\n	HalfSources", "	RewardMult = 0.25,\n	HalfSources"),
    ("quests halved", C, "	HalfSources = { Event = true, War = true, Bounty = true },", "	HalfSources = { Event = true, War = true, Bounty = true, Quest = true },"),
    # the pit's loot
    ("no AreaMult on kills", M, "		AreaMult = typeof(pos) == \"Vector3\" and (Config.PvPAreaAt(pos) or {}).LootMult or nil,\n", ""),
    ("AreaMult unused", L, "	local rowBonus = num(info.RowBonus, 1) * num(info.AreaMult, 1)", "	local rowBonus = num(info.RowBonus, 1)"),
]


def static() -> tuple[int, list[str]]:
    count, failures = 0, []

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    zone = read(SSS / "ZoneService.luau")
    upd = function_block(zone, "local function updateZone(")
    check("applyZone(player, zone, root.Position)" in upd, "updateZone hands every sample to applyZone")
    check("pvpNow[player] = nil" in zone and "pvpNow[player] = false" in zone, "pvpNow is reset on ready and cleanup")
    check("zone.PvP ~= true" not in function_block(zone, "local function combatBlocksTravel("),
          "travel blocking follows where PvP is on (pvpNow)")
    mb = read(SSS / "MapBuilder.luau")
    check("Config.ZoneHasPvP(zone)" in mb, "the map's gate colour sees the ruins' pit")
    return count, failures


SUITE = Suite(
    mark="A2390",
    fixture=ROOT / "tools/fixtures/a2390_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-09/offline_dev2_a2390_2026-10-09.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-90: SkeletonRuins PvP false + PvPArea Crown Pit { Center (1660, 0), Size 200 x 240, LootMult 1.25 }; "
             "Config.PvPAt(pos) = zone PvP or inside a PvP area; ZoneService ZonePvP / IsPvPZone follow the position "
             "(EnteredPvP / EnteredSafe lines when crossing the pit's edge, ZoneChanged only on a zone change); kills in "
             "the pit roll drop rows x LootMult (info.AreaMult); Captain Clatter's fallback spot (1670, 0) in the pit. "
             "Config.PrivateServer: with game.PrivateServerId ~= '' ProgressionService.AddBankGold x0.5 for sources "
             "Event / War / Bounty (before the 2x gold pass), the goose's XP x0.5; Text for the shop card.",
    limitations="ZoneService runs only applyZone (the zone loop, travel and anti-cheat are not here); the reward sites are "
                "checked as source text; the client (boundary marker, minimap colour, shop line) is game dev 1's.",
)

if __name__ == "__main__":
    run(SUITE)
