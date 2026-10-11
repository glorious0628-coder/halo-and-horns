"""Weapon T1~T3 v2 (10/11 night): same 27 shapes as v1 (tools/_weapon_t13_prompts.py) but redrawn with the HQ front as STYLE reference
(chunky glossy look), tier simpler than the HQ. Plus 3 Berserker final one-hand-sword candidates (A23-128).
Writes art/prompts/Weapon_<Key>_v2.txt and build/img2_weapons_t13_v2/queue.json (items for __runList; ref filled by caller).
Run: py tools/_weapon_t13_v2_prompts.py"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from _weapon_t13_prompts import W, HALO, HORN, NEUT  # noqa: E402

HEAD = "Use the attached image only as a rendering-style reference (smooth glossy chunky game prop, thick rounded proportions, short thick blade or handle, big simple shapes); do not copy its shape or colors. "
SIMPLE = {
    "T1": "Much plainer and humbler than the reference: no gold, almost no metal. ",
    "T2": "Plainer than the reference: wood and cloth, only tiny metal accents, no gold bands. ",
    "T3": "Clearly simpler than the reference: dull steel or iron, few small accents, no big gold decoration. ",
}
TAIL = (" One single weapon, standing upright, side view, centered, whole weapon in frame with a wide margin, plain flat medium gray background, shadowless. "
        "Distinct materials; the grip is a plain wrapped section. No hand, no person, no faces, no skulls, no lettering, no blood, no floating parts, no light rays.")

D = dict(W)
# Blacksmith T3: iron bands only, no gold band / ring (HQ hammer is nearly identical otherwise)
D["Neutral_Blacksmith_T3"] = NEUT + " a sturdy blacksmith hammer: a square dull iron hammer head with a flat striking face and a short wedge peen, two plain dark iron bands, a thick wooden handle with a brown leather-wrapped grip, a plain flat end cap. No gold, no brass, no ring."
# Alchemist: ONE hand-held staff only, small flask hangs/sits on the staff (no separate flask or rod beside it)
D["Neutral_Alchemist_T1"] = NEUT + " ONE single humble alchemist staff: a short crooked wooden staff with a cloth-wrapped grip, a small round plain glass vial with a cork hanging from the top by a cord. Nothing else beside it."
D["Neutral_Alchemist_T2"] = NEUT + " ONE single alchemist staff: a smooth wooden staff with a leather-wrapped grip, a round glass flask half full of green liquid with a cork fixed on top in a thin iron holder. Nothing else beside it."
D["Neutral_Alchemist_T3"] = NEUT + " ONE single sturdy alchemist staff: a wooden staff with a leather-wrapped grip and a brass tip, its top holding a round glass flask of glowing green liquid in a plain brass cradle with a stopper. Nothing else beside it."

REF = {  # style reference = HQ front of the same class (key in refs.json), warrior horns uses the paladin sword
    "Halo_Paladin": "Halo_Paladin", "Horns_Berserker": "Halo_Paladin",
    "Halo_LightMage": "Halo_LightMage", "Horns_DarkMage": "Horns_DarkMage",
    "Halo_Ranger": "Halo_Ranger", "Horns_ShadowHunter": "Horns_ShadowHunter",
    "Neutral_Blacksmith": "Neutral_Blacksmith", "Neutral_Alchemist": "Neutral_PetTamer", "Neutral_PetTamer": "Neutral_PetTamer",
}

# Berserker FINAL look candidates: one-hand dark sword, lava-gold cracks + horn guard (HQ material look), A23-128
BF = {
    "Horns_Berserker_final_a": " a one-handed dark steel short sword: a broad leaf-shaped heavy blade with a few small notches and thin glowing orange cracks, an ivory curved horn-shaped cross guard, a red leather-wrapped grip, a heavy round iron pommel.",
    "Horns_Berserker_final_b": " a one-handed dark steel sword: a straight wide blade with a jagged notched edge and thin glowing orange cracks, a short ivory horn-tip cross guard, a red leather-wrapped grip, a round iron pommel with a small orange glowing gem.",
    "Horns_Berserker_final_c": " a one-handed dark steel cleaver sword: a short thick blade with a squared-off tip and thin glowing orange cracks, two ivory horns curling forward as the cross guard, a red leather-wrapped grip, a heavy iron pommel.",
}
BHEAD = "Use the attached image only as a material-style reference (dark cracked steel with thin glowing orange cracks, ivory horn guard, red leather, chunky glossy game prop); do not copy its shape: this is a different, smaller ONE-HANDED short sword, the blade no longer than the handle plus guard times three. "


def main():
    q = []
    for k, d in D.items():
        cls, tier = k.rsplit("_", 1)
        body = HEAD + SIMPLE[tier] + d.strip() + TAIL
        assert len(body) < 1000, (k, len(body))
        ref = REF[cls]
        (ROOT / "art/prompts" / f"Weapon_{k}_v2.txt").write_text(f"[reference: HQ front {ref} (style only), Medium]\n{body}\n", encoding="utf-8")
        q.append({"key": f"Weapon_{k}_v2", "ref": ref, "prompt": body, "quality": "medium"})
    for k, d in BF.items():
        body = BHEAD + d.strip() + TAIL
        assert len(body) < 1000, (k, len(body))
        (ROOT / "art/prompts" / f"Weapon_{k}.txt").write_text(f"[reference: HQ front Horns_Berserker (material only), Medium]\n{body}\n", encoding="utf-8")
        q.append({"key": f"Weapon_{k}", "ref": "Horns_Berserker", "prompt": body, "quality": "medium"})
    out = ROOT / "build/img2_weapons_t13_v2"
    out.mkdir(parents=True, exist_ok=True)
    (out / "queue.json").write_text(json.dumps(q, ensure_ascii=False, indent=1), encoding="utf-8")
    print(len(q), "items; max len", max(len(i["prompt"]) for i in q))


if __name__ == "__main__":
    main()
