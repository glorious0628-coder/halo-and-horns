"""Add the in-game held length ('code_len') to every art/models/tripo/weapons/*/*_HD_fit.json (무기 디자인, 10/14).
The GLBs stay at Config.Weapons Length (3 / 3.5 / 4 for T1~T3, 최종 검수); CharacterVisuals sizes the MeshPart to these
(개발 1): sword = hilt 1.2 + guard 0.25 + blade lerp(2.4, 3.1); staff = avatar height x lerp(0.65, 0.75) (5.18 default);
bow = lerp(3.1, 4.9), short bow x 0.75; hammer = handle 1.9 + head 0.3; baton = shaft 1.8 + tip; t = (Length - 3) / 3.5.
  py tools/weapon_code_len.py
"""
import glob
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KIND = {"Paladin": "Sword", "Berserker": "DarkSword", "Blacksmith": "Hammer", "LightMage": "Staff", "DarkMage": "CrookStaff",
        "Alchemist": "FlaskStaff", "Ranger": "Bow", "ShadowHunter": "ShortBow", "PetTamer": "Baton"}
LENGTH = {1: 3.0, 2: 3.5, 3: 4.0}
lerp = lambda a, b, t: a + (b - a) * t
for p in sorted(glob.glob(os.path.join(ROOT, "art", "models", "tripo", "weapons", "*", "*_HD_fit.json"))):
    m = re.search(r"Weapon_(Halo|Horns|Neutral)_([A-Za-z]+)_T(\d)", p)
    if not m:
        continue
    cls, tier = m.group(2), int(m.group(3))
    t = (LENGTH[tier] - 3) / 3.5
    kind = KIND[cls]
    if kind in ("Sword", "DarkSword"):
        L, note = 1.2 + 0.25 + lerp(2.4, 3.1, t), "sword: hilt 1.2 + guard 0.25 + blade lerp(2.4,3.1)"
    elif kind in ("Staff", "CrookStaff", "FlaskStaff"):
        L, note = 5.18 * lerp(0.65, 0.75, t), "staff: avatar height x lerp(0.65,0.75); 5.18 = default R15"
    elif kind == "Bow":
        L, note = lerp(3.1, 4.9, t), "bow: lerp(3.1,4.9)"
    elif kind == "ShortBow":
        L, note = 0.75 * lerp(3.1, 4.9, t), "short bow: 0.75 x lerp(3.1,4.9)"
    elif kind == "Hammer":
        L, note = 2.2, "hammer: handle 1.9 + head half 0.3 (fixed)"
    else:
        L, note = 1.8 + 0.35 + 0.04 * tier, "baton: shaft 1.8 + tip ball"
    d = json.load(open(p))
    d["code_len"] = {"kind": kind, "studs": round(L, 3), "rule": note, "src": "CharacterVisuals.luau tierLen / LEN (10/14)",
                     "note": "GLB stays at Config Length; the code sizes the MeshPart to code_len (개발 1)"}
    json.dump(d, open(p, "w"), indent=1)
    print(os.path.basename(p), kind, round(L, 3))
