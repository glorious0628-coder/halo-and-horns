"""A23-108 class weapon 2D (9 weapons + Paladin shield). Front prompts (High) -> art/prompts/Weapon_<Key>_front.txt + build/img2_halo_mv/weapon_fronts.json
Back / side views reuse the front as reference (see weapon_views in the same json). Run: py tools/_weapon_prompts.py"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEAD = "Use the attached image only as a style reference. Draw only this one weapon, standing upright as a standalone prop, "
HALO = " Style: white marble-white and bright yellow polished gold with pale sky-blue gems."
HORN = " Style: dark purple-black steel and dark wood with ivory horn parts, deep red leather, faint warm orange glow in cracks."
NEUT = " Style: warm brown wood, grey iron and brass."
TAIL = (" Straight side-on view, perfectly upright, centered, the whole weapon in frame with a wide empty margin, plain flat medium gray background, shadowless. "
        "Glossy chunky toy-like 3D render with soft rounded bevels; clearly different materials: polished metal, wood grain, wrapped leather, faceted gems; the hand grip is a clearly separate, plain wrapped section. "
        "No hand, no person, no faces, no skulls, no lettering, no blood, no floating rings, no light rays or beams.")

W = {
    "Halo_Paladin": HALO + " a straight longsword: long polished silver-white blade with a gold central groove and a pointed tip, a gold cross guard with two small round sky-blue gems, a white leather-wrapped grip with gold rings, a round gold pommel.",
    "Halo_LightMage": HALO + " a tall wizard staff: slim white wooden shaft with gold rings, the top holds a glowing round warm-white orb in a gold claw cradle with two small gold wing shapes, a short pointed gold ferrule at the bottom.",
    "Halo_Ranger": HALO + " a long recurve bow, strung with a thin taut string: smooth white wood limbs with gold tips and gold inlay, a sky-blue leather-wrapped grip in the middle.",
    "Horns_Berserker": HORN + " a one-handed dark steel sword of normal length: a medium-length dark steel blade with a notched sawtooth edge and thin glowing orange cracks, a short one-hand handle wrapped in red leather, an ivory curved horn-shaped cross guard, a round iron pommel with a small orange glowing gem.",
    "Horns_DarkMage": HORN + " a curved crook staff: a twisted dark wooden shaft ending in a hooked crook at the top that holds a glowing purple orb, a few small ivory spikes and iron bands, a pointed iron ferrule at the bottom.",
    "Horns_ShadowHunter": HORN + " a short recurved hunting bow, strung with a thin string: black and dark purple wood limbs with ivory tip spikes and a red leather-wrapped grip.",
    "Neutral_Blacksmith": NEUT + " a blacksmith hammer: a big square iron hammer head with a flat striking face and a small wedge peen on the back, a thick wooden handle with a brown leather-wrapped grip and an iron ring at the bottom.",
    "Neutral_Alchemist": NEUT + " an alchemist set shown side by side: a round glass flask half full of glowing green liquid with a cork stopper and a brass band, next to a short wooden stirring rod with a leather-wrapped grip and a brass tip.",
    "Neutral_PetTamer": NEUT + " a short trainer's baton: a slim wooden shaft with a leather-wrapped grip, a small round brass knob at the back end and a brass tip with a small green gem at the front.",
    "Halo_PaladinShield": HALO + " a small round shield (a buckler) shown straight on the face: a white marble-colored rim with gold trim, a bright gold boss in the center with a sky-blue gem, a plain smooth pale face with no emblem, a plain strap handle seen from the back is not shown.",
}


def main():
    ref_note = "[reference: weapon style collage (chunky props), High]"
    fr = []
    for k, d in W.items():
        body = HEAD + d + TAIL
        assert len(body) < 1000, (k, len(body))
        (ROOT / "art/prompts" / f"Weapon_{k}_front.txt").write_text(f"{ref_note}\n{body}\n", encoding="utf-8")
        short = d.split(":")[0].strip().split("Style:")[-1]
        fr.append({"key": k, "prompt": body, "desc": d})
    (ROOT / "build/img2_halo_mv/weapon_fronts.json").write_text(json.dumps(fr, ensure_ascii=False), encoding="utf-8")
    print(len(fr), max(len(x["prompt"]) for x in fr))


if __name__ == "__main__":
    main()
