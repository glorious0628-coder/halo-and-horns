"""⑤ spawn protection without the bubble: an invisible ForceField + a faction-color outline (Highlight), offline.

Runs the same CURRENT sources as tools/test_ranking.py (whole PvPService, CombatService, GrudgeService, RankingService,
AnnounceService, LootService, TitleService, Config, Util + the PlayerService fame / activity extract) on
tools/fixtures/dev2_world.luau (rankWorld { PvPLoop = true }: PvPService's 1 s loop stepped by hand) with
tools/fixtures/protect_glow_offline.luau, with the installed official Luau CLI. No Studio, network, DataStore or
Roblox API calls. Mutations run on in-memory copies of the sources only.

Spec: docs/design/quality_ideas (eaf41cc) §1-⑤, 검수 2026-10-07.
Usage: py tools/test_protect_glow.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_dev2_protect_glow_2026-10-06.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SSS, Suite, function_block, read, run
from test_ranking import FILES as RANKING_FILES, bindings

FILES = dict(RANKING_FILES)
P, C = "PVP_SOURCE", "CONFIG_SOURCE"

MUTATIONS = [
    ("the bubble shows again", P, "\t\tff.Visible = false -- ⑤ no bubble", "\t\tff.Visible = true -- ⑤ no bubble"),
    ("no outline on a spawn", P, "\tsetAttr(player, \"Protected\", true)\n\taddProtectGlow(player)\n",
     "\tsetAttr(player, \"Protected\", true)\n"),
    ("the outline stays after the shield", P,
     'if child:IsA("ForceField") or (child:IsA("Highlight") and child.Name == PROTECT_GLOW) then',
     'if child:IsA("ForceField") then'),
    ("a filled glow", P, "\th.FillTransparency = 1\n", "\th.FillTransparency = 0.5\n"),
    ("seen through walls", P, "\th.DepthMode = Enum.HighlightDepthMode.Occluded\n",
     "\th.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop\n"),
    ("one color for both sides", P, "\th.OutlineColor = f.Color\n", "\th.OutlineColor = Config.Factions.Halo.Color\n"),
    ("a hard outline", P, "\th.OutlineTransparency = Config.PvP.ProtectGlow.OutlineTransparency\n",
     "\th.OutlineTransparency = 0\n"),
    ("a second outline on a second Protect", P,
     "or character:FindFirstChild(PROTECT_GLOW) or not (f and f.Color) or inTown(p) then", "or not (f and f.Color) or inTown(p) then"),
    ("a rebuilt body stays bare", P,
     "\telseif pu and pu > 0 then\n\t\tif inTown(p) then removeProtectGlow(p) else addProtectGlow(p) end\n\tend\n", "\tend\n"),
    ("the loop dresses unprotected bodies", P, "\telseif pu and pu > 0 then\n\t\tif inTown(p)",
     "\telse\n\t\tif inTown(p)"),
    ("the shield stays after a hit", P, "\tprotectedUntil[player] = 0\n\tdestroyForceFields(player)\n",
     "\tprotectedUntil[player] = 0\n"),
    # 빛 마을 점검 #42: no outline in a town
    ("#42 an outline in town", P, " or not (f and f.Color) or inTown(p) then", " or not (f and f.Color) then"),
    ("#42 the loop keeps the town outline", P, "\t\tif inTown(p) then removeProtectGlow(p) else addProtectGlow(p) end\n",
     "\t\taddProtectGlow(p)\n"),
    ("#42 town takes the shield too", P, "\t\tif inTown(p) then removeProtectGlow(p) else addProtectGlow(p) end\n",
     "\t\tif inTown(p) then destroyForceFields(p) else addProtectGlow(p) end\n"),
    ("#42 never an outline", P, "\treturn ok and town == true\nend", "\treturn true\nend"),
    ("a solid outline in Config", C, "ProtectGlow = { OutlineTransparency = 0.35 },", "ProtectGlow = { OutlineTransparency = 0 },"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    pvp = read(SSS / "PvPService.luau")
    check("ff.Visible = true" not in pvp, "no visible ForceField anywhere in PvPService")
    check(pvp.count('Instance.new("ForceField")') == 1, "one place makes the shield (Protect)")
    protect = function_block(pvp, "function PvPService.Protect(")
    check("addProtectGlow(player)" in protect, "Protect adds the outline")
    # nothing else in the game makes a visible ForceField (PlayerService only moves / removes them)
    for path in sorted(SSS.glob("*.luau")):
        text = read(path)
        if path.name != "PvPService.luau":
            check('Instance.new("ForceField")' not in text, f"{path.name} makes no ForceField")
    mapb = read(SSS / "MapBuilder.luau")
    check("spawn.Duration = 0" in mapb, "the SpawnLocation adds no engine bubble (Duration 0)")
    return count, failures


SUITE = Suite(
    mark="PROTECT_GLOW",
    fixture=ROOT / "tools/fixtures/protect_glow_offline.luau",
    world=ROOT / "tools/fixtures/dev2_world.luau",
    out=ROOT / "docs/art/verification_2026-10-06/offline_dev2_protect_glow_2026-10-06.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="⑤ (quality_ideas §1, 검수 2026-10-07): PvPService.Protect (spawn, 10 s) keeps the ForceField (Humanoid:"
             "TakeDamage still respects it) but Visible = false, and puts a Highlight \"ProtectGlow\" on the body: no "
             "fill (FillTransparency 1), OutlineColor = Config.Factions[faction].Color (Halo gold, Horns red), "
             "OutlineTransparency = Config.PvP.ProtectGlow.OutlineTransparency (0.35), DepthMode Occluded. One shield, one "
             "outline. The outline goes with the shield (BreakProtection after the protected player's hit, the expiry in "
             "the 1 s loop); while protected the loop puts it back on a rebuilt body (an appearance swap moves the "
             "ForceField, not the outline), and a cosmetic spawn never renews the time. The Protected attribute (the "
             "'Revive Shield' chip) is unchanged. 빛 마을 점검 #42: no outline while the protected player stands in a town "
             "(ZoneService.IsTown: no PvP there); the loop puts it on once they walk out and takes it off back inside; "
             "the shield and its 10 s are unchanged.",
    limitations="The real look (outline width, how it reads on avatars at a distance, phone) needs a Studio check by game "
                "dev 1. Roblox draws at most 31 Highlights at once per client; spawn shields last 10 s, so only a few "
                "exist at a time. A body that also wears the 3-star WantedGlow shows both Highlights.",
)

if __name__ == "__main__":
    run(SUITE)
