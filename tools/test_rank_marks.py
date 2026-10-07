"""계급 장식 3D: the rank's own halo / horns model on the head (CharacterVisuals.buildFactionMark), offline.
Also UI round 2 #7: the server-built name tags use the game's fonts from Config.Fonts (tagFont / makeLine /
createNametag).

Cuts attrNum, markTemplate, buildMarkModel and buildFactionMark (and attrNum, tagFont, makeLine, nametagOffset,
createNametag for the name tag) from the CURRENT CharacterVisuals (with the CURRENT Config and Util) and runs them on tools/fixtures/dev2_kit.luau doubles with tools/fixtures/rank_marks_offline.luau and
the installed official Luau CLI. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of
the sources only.

Usage: py tools/test_rank_marks.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_dev2_rank_marks_2026-10-06.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "VISUALS_SOURCE": SSS / "CharacterVisuals.luau",
}
C, V = "CONFIG_SOURCE", "VISUALS_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    visuals = sources[V]
    slots = re.search(r"^local MARK_HEAD_SLOTS = .*$", visuals, re.M)
    if not slots:
        raise ValueError("CharacterVisuals MARK_HEAD_SLOTS missing; update the test extractor.")
    head_slots = slots.group(0)
    return {
        "CONFIG_SOURCE": sources[C],
        "UTIL_SOURCE": sources["UTIL_SOURCE"],
        "MARKS_EXTRACT": (
            "local Config, Util, ServerStorage, newPiece, mount, accPart, addLight, sparkle, clearChild, getFaction, "
            "charScale, buildNeutralGear = ...\nlocal V = Config.Visuals\nlocal NEUTRAL_ID = \"Neutral\"\n"
            + head_slots + "\n"
            + function_block(visuals, "local function attrNum(")
            + function_block(visuals, "local function markTemplate(")
            + function_block(visuals, "local function markFloor(")
            + function_block(visuals, "local function buildMarkModel(")
            + function_block(visuals, "local function buildFactionMark(")
            + "\nreturn buildFactionMark\n"),
        "NAMETAG_EXTRACT": (
            "local Config = ...\nlocal V = Config.Visuals\nlocal MIN_TEXT_SIZE = 11\n"
            "local LINE2_COLOR, LINE3_COLOR = Color3.fromRGB(235, 235, 240), Color3.fromRGB(255, 70, 70)\n"
            + function_block(visuals, "local function attrNum(")
            + function_block(visuals, "local function tagFont(")
            + function_block(visuals, "local function makeLine(")
            + function_block(visuals, "local function nametagOffset(")
            + function_block(visuals, "local function createNametag(")
            + "\nreturn { create = createNametag, tagFont = tagFont }\n"),
    }


MUTATIONS = [
    ("the rank model is never used", V, "\tlocal template = markTemplate(f, rank)\n", "\tlocal template = nil\n"),
    ("always the rank 1 model", V, "names[math.clamp(rank, 1, #names)]", "names[1]"),
    ("no scale for bigger heads", V, "\tpart.Size = template.Size * k * (type(M.RankScale)",
     "\tpart.Size = template.Size * (type(M.RankScale)"),
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
    # 3rd idea round #6: on top of hair and hats, R1 / R2 bigger
    ("hair and hats are ignored", V,
     "floor = math.max(floor, head.CFrame:PointToObjectSpace(handle.Position).Y + handle.Size.Y / 2)", "floor = floor"),
    ("no cap for giant hats", V, "return math.min(floor, top + (V.MarkModels.MaxRise or 1) * k)", "return floor"),
    ("the cap ignores the head size", V, "top + (V.MarkModels.MaxRise or 1) * k)", "top + (V.MarkModels.MaxRise or 1))"),
    ("every accessory lifts the mark", V, 'if a:IsA("Attachment") and MARK_HEAD_SLOTS[a.Name] then onHead = true end',
     'if a:IsA("Attachment") then onHead = true end'),
    ("AccessoryType Hat / Hair is ignored", V,
     "onHead = ok and (kind == Enum.AccessoryType.Hat or kind == Enum.AccessoryType.Hair)", "onHead = false"),
    ("the mark ignores the floor", V, "markFloor(character, head, k) + lift", "head.Size.Y / 2 + lift"),
    ("R1 / R2 keep the small size", V, " * (type(M.RankScale) == \"table\" and tonumber(M.RankScale[rank]) or 1)", ""),
    ("Config: R1 not bigger", C, "RankScale = { 1.4, 1.2 },", "RankScale = { 1, 1.2 },"),
    ("Config: R2 not bigger", C, "RankScale = { 1.4, 1.2 },", "RankScale = { 1.4, 1 },"),
    ("Config: a high cap", C, "MaxRise = 1.0,", "MaxRise = 3.0,"),
    # UI round 2 #7: name tag fonts
    ("name tags keep GothamBold", V, "\tif ok and face then label.FontFace = face end\n", ""),
    ("no guard when Config.Fonts is missing", V, "\tlocal fonts = Config.Fonts or {}\n", "\tlocal fonts = Config.Fonts\n"),
    ("Config: the name line in the Body font", C, 'Nametag = { Line1 = "Head",', 'Nametag = { Line1 = "Body",'),
    ("Config: Denk One swapped for Montserrat", C, 'Head = "rbxasset://fonts/families/DenkOne.json",',
     'Head = "rbxasset://fonts/families/Montserrat.json",'),
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
    spawned = function_block(visuals, "local function onCharacterSpawned(")
    added = spawned.find("character.ChildAdded:Connect")
    removed = spawned.find("character.ChildRemoved:Connect")
    check(added >= 0 and 'elseif child:IsA("Accessory") then' in spawned[added:removed]
          and 'task.delay(REFRESH_DEBOUNCE, markDirty, player, { "FactionMark" })' in spawned[added:removed],
          "3rd idea round #6: a hat / hair added later rebuilds the mark (after the weld settles)")
    check(removed >= 0 and 'if child:IsA("Accessory") then markDirty(player, { "FactionMark" }) end' in spawned[removed:],
          "3rd idea round #6: a removed hat / hair rebuilds the mark")
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
