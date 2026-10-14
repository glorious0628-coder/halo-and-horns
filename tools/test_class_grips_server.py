"""A23-108 ② weapon shapes per class x side (게임성 개발 1 proposal, 개발 3 checks), static / offline.

Reads the CURRENT Config.luau (Config.ClassGrips) and CharacterVisuals.luau. Checks: every ClassGrips Weapon has a shape
(a SHAPES builder or the old Sword / Staff / Bow / Baton), buildWeapon takes the weapon from ClassGrips first and the old
rule (tamer baton, the class's weapon) without a row, A23-150 7 (user 10/12 (가)): every weapon - the bows too - in the
RIGHT hand (a Roblox Tool), both bows get the arrow muzzle and publish the LEFT hand's draw spots (AttackHand, HandMuzzle,
HandBowRest: Fx moves the bow there while an archer clip plays), the short bow is the bow at 0.75 size canted 15
degrees (Config.WeaponGrips ShortBow Turn), the shapes are plain Parts (no store assets). Mutations on in-memory
copies: each must be caught. The look is checked in Studio photos (메인 반영 1). Geometry: tools/test_tool_grip.py.

Usage: py tools/test_class_grips_server.py
Report: docs/art/verification_2026-10-10/offline_class_grips_server_2026-10-10.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
CV = ROOT / "src/ServerScriptService/CharacterVisuals.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
OUT = ROOT / "docs/art/verification_2026-10-10/offline_class_grips_server_2026-10-10.json"
OLD = {"Sword", "Staff", "Bow", "Baton"}


def checks(cv: str, cfg: str) -> list[tuple[str, bool]]:
    block = cfg[cfg.find("Config.ClassGrips = {"):cfg.find("function Config.ClassGripKey")]
    weapons = re.findall(r'(\w+_\w+) = \{ Weapon = "(\w+)"', block)
    shapes = set(re.findall(r"^function SHAPES\.(\w+)\(", cv, re.M))
    out = [("nine ClassGrips rows with a weapon", len(weapons) == 9)]
    for key, kind in weapons:
        out.append((f"{key}: its weapon '{kind}' has a shape", kind in shapes or kind in OLD))
    grips = cfg[cfg.find("Config.WeaponGrips = {"):cfg.find("function Config.WeaponGripOf")]
    out += [
        ("buildWeapon reads ClassGrips first", 'local gdef = type(Config.ClassGrips) == "table" and gkey and Config.ClassGrips[gkey] or nil' in cv
         and 'local kind = (type(gdef) == "table" and type(gdef.Weapon) == "string" and gdef.Weapon)' in cv),
        ("... and the old rule without a row", 'or ((Config.IsTamer and Config.IsTamer(classId, getFaction(player))) and "Baton" or classDef.Weapon)' in cv),
        ("a SHAPES builder is used by its kind", "local shape = type(SHAPES) == \"table\" and SHAPES[kind] or nil" in cv
         and "parts, main = shape(CFrame.identity, sc, w, color, tier, staffHeight, point)" in cv),  # A23-150 7: round its Handle
        ("A23-150 7: every weapon in the right hand (the bows too)", 'local hand = Util.FindPart(character, "RightHand", "Right Arm")' in cv
         and 'local left = kind == "Bow"' not in cv),
        ("both bows get the arrow muzzle", 'local isBow = kind == "Bow" or kind == "ShortBow"' in cv
         and "if isBow then\n\t\t\tmuzzle.Position = Vector3.new(0, 0, -0.18 * sc)" in cv),
        ("both bows publish the left hand's draw spots (AttackHand, HandMuzzle, HandBowRest)",
         'local left = isBow and Util.FindPart(character, "LeftHand", "Left Arm") or nil' in cv
         and 'model:SetAttribute("AttackHand", left.Name)' in cv
         and 'model:SetAttribute("HandMuzzle", toLeft * (main.CFrame * muzzle.CFrame))' in cv
         and 'if nock then model:SetAttribute("HandBowRest", toLeft * (part.CFrame * nock.CFrame)) end' in cv),
        ("the short bow = the bow at 0.75, canted 15 degrees", "return buildBow(H, sc, w, color, 0.75)" in cv
         and "local len = tierLen(w, LEN.Bow) * (tonumber(scale) or 1)" in cv  # A23-133: the bow length from LEN
         and "ShortBow = { Point = 0.5, Turn = { 0, 0, 15 }" in grips),  # A23-187: + Rest / Hold after the turn
        ("the shapes are plain parts (no store asset ids)", "rbxassetid" not in cv[cv.find("local SHAPES = {}"):cv.find("local function buildWeapon(")]),
    ]
    return out


MUTATIONS = [
    ("the hammer never made", "function SHAPES.Hammer(", "function SHAPES.Hammer_("),
    ("A23-128: the dark one-hand sword never made", "function SHAPES.DarkSword(", "function SHAPES.DarkSword_("),
    ("ClassGrips ignored", 'local kind = (type(gdef) == "table" and type(gdef.Weapon) == "string" and gdef.Weapon)', "local kind = (false)"),
    ("A23-150 7: the bow in the left hand again", 'local hand = Util.FindPart(character, "RightHand", "Right Arm")',
     'local left = kind == "Bow"\n\tlocal hand = Util.FindPart(character, left and "LeftHand" or "RightHand", "Right Arm")'),
    ("the short bow has no arrow muzzle", 'local isBow = kind == "Bow" or kind == "ShortBow"', 'local isBow = kind == "Bow"'),
    ("the bow's draw spots in the right hand's space", 'model:SetAttribute("HandMuzzle", toLeft * (main.CFrame * muzzle.CFrame))',
     'model:SetAttribute("HandMuzzle", hand.CFrame:ToObjectSpace(main.CFrame * muzzle.CFrame))'),
    ("the short bow full size", "return buildBow(H, sc, w, color, 0.75)", "return buildBow(H, sc, w, color)"),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    cv = CV.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    cfg = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    res = checks(cv, cfg)
    for name, ok in res:
        print(("CHECK_OK  " if ok else "CHECK_FAIL ") + name)
    muts = []
    for name, old, new in MUTATIONS:
        hits = cv.count(old)
        caught = hits == 1 and not all(ok for _, ok in checks(cv.replace(old, new), cfg))
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    failed = sum(0 if ok else 1 for _, ok in res)
    ok = failed == 0 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": len(res), "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {len(res)}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
