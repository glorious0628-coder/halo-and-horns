"""계급 장식 3D: the rank's own halo / horns model on the head (CharacterVisuals.buildFactionMark), offline.

Cuts attrNum, markTemplate, buildMarkModel and buildFactionMark from the CURRENT CharacterVisuals (with the CURRENT
Config and Util) and runs them on tools/fixtures/dev2_kit.luau doubles with tools/fixtures/rank_marks_offline.luau and
the installed official Luau CLI. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of
the sources only.

Usage: py tools/test_rank_marks.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_dev2_rank_marks_2026-10-06.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "VISUALS_SOURCE": SSS / "CharacterVisuals.luau",
}
C, V = "CONFIG_SOURCE", "VISUALS_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    visuals = sources[V]
    return {
        "CONFIG_SOURCE": sources[C],
        "UTIL_SOURCE": sources["UTIL_SOURCE"],
        "MARKS_EXTRACT": (
            "local Config, Util, ServerStorage, newPiece, mount, accPart, addLight, sparkle, clearChild, getFaction, "
            "charScale, buildNeutralGear = ...\nlocal V = Config.Visuals\nlocal NEUTRAL_ID = \"Neutral\"\n"
            + function_block(visuals, "local function attrNum(")
            + function_block(visuals, "local function markTemplate(")
            + function_block(visuals, "local function buildMarkModel(")
            + function_block(visuals, "local function buildFactionMark(")
            + "\nreturn buildFactionMark\n"),
    }


MUTATIONS = [
    ("the rank model is never used", V, "\tlocal template = markTemplate(f, rank)\n", "\tlocal template = nil\n"),
    ("always the rank 1 model", V, "names[math.clamp(rank, 1, #names)]", "names[1]"),
    ("no scale for bigger heads", V, "\tpart.Size = template.Size * k\n", "\tpart.Size = template.Size\n"),
    ("the halo sits on the head", V, "(M.HaloGap or 0.3) * k", "0"),
    ("the horns float", V, "-(M.HornsDepth or 0.06) * k", "(M.HornsDepth or 0.06) * k"),
    ("the model ignores Config Yaw (faces its back)", V, "CFrame.Angles(0, math.rad(M.Yaw or 0), 0)",
     "CFrame.Angles(0, math.rad(180), 0)"),
    ("an anchored accessory", V, "\tpart.Anchored = false\n", ""),
    ("a colliding accessory", V, "\tpart.CanCollide = false\n", ""),
    ("no halo light", V, "\tif f == \"Halo\" and type(M.HaloLight) == \"table\" then", "\tif false then"),
    ("sparkles at every rank", V, "rank >= (glow.Rank or 5)", "rank >= 1"),
    ("a Model template is skipped", V,
     '\tif t and t:IsA("Model") then t = t:FindFirstChildWhichIsA("BasePart", true) end\n', ""),
    ("Config: no R5 glow", C, "Glow = { Rank = 5,", "Glow = { Rank = 6,"),
    ("Config: the halo on the head", C, "HaloGap = 0.3,", "HaloGap = 0,"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    visuals = read(SSS / "CharacterVisuals.luau")
    check('local ServerStorage = game:GetService("ServerStorage")' in visuals, "CharacterVisuals reads ServerStorage")
    mark = function_block(visuals, "local function buildFactionMark(")
    check(mark.find("markTemplate(f, rank)") < mark.find("HaloDisc"), "the rank model comes before the drawn fallback")
    for i in range(1, 6):
        for kind in ("Halo", "Horns"):
            check((ROOT / f"art/models/acc/Acc_{kind}R{i}.glb").is_file(), f"art/models/acc/Acc_{kind}R{i}.glb is on disk")
    return count, failures


SUITE = Suite(
    mark="RANK_MARKS",
    fixture=ROOT / "tools/fixtures/rank_marks_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-06/offline_dev2_rank_marks_2026-10-06.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="계급 장식 3D (이미지 생성 1 45b6220, user OK): Halo / Horns rank r (Config.GetTitle) wears "
             "ServerStorage[Config.Visuals.MarkModels.Folder] Acc_HaloR<r> / Acc_HornsR<r> (a MeshPart, or a Model with "
             "one mesh) cloned, sized x head height / HeadRef (1.2), its bottom HaloGap (0.3) above / HornsDepth (0.06) "
             "into the head top (both x k), turned by Yaw, unanchored / massless / no collision, welded to the head; "
             "halos get the old PointLight, rank >= Glow.Rank (5) sparkles. A missing model keeps the drawn mark; "
             "the guild keeps its gear.",
    limitations="The import itself (GLB -> MeshPart in ServerStorage.MarkModels, the asset upload) and the real look on "
                "avatars (Yaw 0: the models were turned to face Roblox -Z before the import, 427baf8) are checked in Studio "
                "by game dev 1. CFrame is a "
                "translation + yaw stand-in (the test head never turns).",
)

if __name__ == "__main__":
    run(SUITE)
