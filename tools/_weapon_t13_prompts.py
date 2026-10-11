"""A23-108/128 class weapon tiers T1~T3, 9 weapons x 3 tiers = 27 Medium candidates (0 credits).
Warriors are one-hand swords in BOTH factions (A23-128). Writes art/prompts/Weapon_<Key>_T<n>.txt and build/img2_weapons_t13/queue.json
(items for tools/_firefly_helpers.js __runNoRef: {key, prompt, quality:'medium'}). Run: py tools/_weapon_t13_prompts.py"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEAD = "Draw only this one weapon, standing upright as a standalone prop, "
TAIL = (" Straight side-on view, perfectly upright, centered, the whole weapon in frame with a wide empty margin, plain flat medium gray background, shadowless. "
        "Glossy chunky toy-like 3D render with soft rounded bevels; clearly different materials: wood grain, wrapped cloth or leather, metal; the hand grip is a clearly separate, plain wrapped section. "
        "No hand, no person, no faces, no skulls, no lettering, no blood, no floating rings, no light rays or beams.")
HALO = " Palette: warm light wood with white cloth and a little pale gold, pale sky-blue accents."
HORN = " Palette: dark purple-brown wood and dark steel with ivory horn parts, deep red cloth, a small purple accent."
NEUT = " Palette: warm brown wood, grey iron and brass."

# tier look: T1 humble branch/stick, T2 smooth carved wood, T3 sturdy iron-reinforced (matches the old generic T1~T3 ladder)
W = {
    # --- one-hand swords (Warrior) ---
    "Halo_Paladin_T1": HALO + " a humble one-handed twig sword: a straight chunky tree-branch used as a sword with pale bark, two tiny green leaves near the tip, a white cloth strip wrapped as the grip, a tiny gold ring under the grip.",
    "Halo_Paladin_T2": HALO + " a one-handed wooden practice sword: a smooth carved light wooden straight blade with a rounded tip, a white-painted wooden cross guard with gold corner caps, a white cord-wrapped grip, a round wooden pommel with a gold cap.",
    "Halo_Paladin_T3": HALO + " a sturdy one-handed iron short sword: a straight broad silver-grey steel blade with a pointed tip and a shallow center groove, a plain gold-trimmed straight cross guard, a white leather-wrapped grip, a round iron pommel with a small sky-blue gem.",
    "Horns_Berserker_T1": HORN + " a humble one-handed thorn-branch sword: a crooked dark twisted branch with small thorn bumps used as a sword, a red cloth strip wrapped as the grip, a tiny ivory bead at the pommel.",
    "Horns_Berserker_T2": HORN + " a one-handed wooden practice sword: a smooth carved dark wooden blade with a rounded tip and a notched edge, a dark wooden cross guard with two small ivory horn tips, a red cord-wrapped grip, a round wooden pommel.",
    "Horns_Berserker_T3": HORN + " a sturdy one-handed dark iron short sword: a broad dark steel blade with a slightly notched edge and a pointed tip, a short iron cross guard bending into two small ivory horn tips, a red leather-wrapped grip, a heavy round iron pommel.",
    # --- staffs (Mage) ---
    "Halo_LightMage_T1": HALO + " a humble dry staff: a gnarled pale wooden walking stick with a few knots, a small curl at the top, a white ribbon tied below the curl with one small white feather.",
    "Halo_LightMage_T2": HALO + " a wooden staff: a smooth white-painted wooden shaft with a spiral-curled top holding one small round pale glass bead, a thin gold ring band, a white cloth wrap grip.",
    "Halo_LightMage_T3": HALO + " a sturdy iron staff: a pale wooden shaft with polished steel ring bands, its head a chunky steel cage of curved prongs with two small gold wing shapes holding a round pale glowing orb, a pointed steel foot cap.",
    "Horns_DarkMage_T1": HORN + " a humble hooked staff: a gnarled dark twisted branch with a small hook at the top, a red cord wrapped below the hook with one small ivory tooth hanging from it.",
    "Horns_DarkMage_T2": HORN + " a wooden crook staff: a smooth dark carved wooden shaft ending in a hooked crook holding one small round purple glass bead, a thin iron ring band, a red cloth wrap grip.",
    "Horns_DarkMage_T3": HORN + " a sturdy iron crook staff: a dark wooden shaft with polished dark steel ring bands, its head a chunky iron hook cage with two small ivory spikes holding a round purple orb, a pointed iron foot cap.",
    # --- bows (Archer) ---
    "Halo_Ranger_T1": HALO + " a humble branch bow: a small crude bow bent from a pale tree branch with a white cloth-wrapped grip, one tiny green leaf near the top tip, a simple twine string, the bow alone.",
    "Halo_Ranger_T2": HALO + " a wooden longbow: smooth carved light wooden limbs with thin white paint stripes and small gold tip caps, a white leather grip, a cream string, the bow alone.",
    "Halo_Ranger_T3": HALO + " a sturdy iron recurve bow: light wooden limbs reinforced with polished steel plates and gold-trimmed steel tip caps, a sky-blue leather grip, a thin taut string, the bow alone.",
    "Horns_ShadowHunter_T1": HORN + " a humble branch bow: a small crude bow bent from a dark twisted branch with a red cloth-wrapped grip, one small ivory bead at the top tip, a simple dark twine string, the bow alone.",
    "Horns_ShadowHunter_T2": HORN + " a wooden short hunting bow: smooth carved dark wooden recurved limbs with small ivory tip spikes, a red leather grip, a dark string, the bow alone.",
    "Horns_ShadowHunter_T3": HORN + " a sturdy iron recurve bow: dark wooden limbs reinforced with polished dark steel plates and ivory tip spikes, a red leather grip, a thin taut string, the bow alone.",
    # --- artisan guild (Neutral) ---
    "Neutral_Blacksmith_T1": NEUT + " a humble stone hammer: a rough grey stone head tied with leather cord to a short crooked wooden handle, a cloth-wrapped grip.",
    "Neutral_Blacksmith_T2": NEUT + " a small blacksmith hammer: a small square dull iron hammer head with a flat striking face, a smooth wooden handle with a brown leather-wrapped grip.",
    "Neutral_Blacksmith_T3": NEUT + " a sturdy blacksmith hammer: a big square iron hammer head with a flat striking face and a small wedge peen, two brass bands, a thick wooden handle with a brown leather-wrapped grip and an iron ring at the bottom.",
    "Neutral_Alchemist_T1": NEUT + " a humble alchemist set shown side by side: a small round plain glass vial with a cork stopper and a little green liquid, next to a short crooked wooden stirring stick with a cloth-wrapped grip.",
    "Neutral_Alchemist_T2": NEUT + " an alchemist set shown side by side: a round glass flask half full of green liquid with a cork stopper and a thin brass band, next to a short smooth wooden stirring rod with a leather-wrapped grip.",
    "Neutral_Alchemist_T3": NEUT + " a sturdy alchemist set shown side by side: a round glass flask in a brass cradle with a brass stopper, full of glowing green liquid, next to a short brass-tipped stirring rod with a leather-wrapped grip.",
    "Neutral_PetTamer_T1": NEUT + " a humble twig baton: a short simple brown stick with a cloth-wrapped handle, one tiny green leaf at the tip and a small wooden whistle tied to the handle with twine.",
    "Neutral_PetTamer_T2": NEUT + " a wooden training baton: a short smooth carved wooden baton with a rounded tip, a teal cloth ribbon wrapped around the handle and a small round wooden paw charm on the handle end.",
    "Neutral_PetTamer_T3": NEUT + " a sturdy iron training baton: a short dark teal shaft with polished steel ring bands, a round steel ball tip, a steel handle cap and a small brass whistle fixed to the handle.",
}


def main():
    q = []
    for k, d in W.items():
        body = HEAD + d.strip() + TAIL
        assert len(body) < 1000, (k, len(body))
        (ROOT / "art/prompts" / f"Weapon_{k}.txt").write_text(f"[no reference, Medium]\n{body}\n", encoding="utf-8")
        q.append({"key": "Weapon_" + k, "prompt": body, "quality": "medium"})
    out = ROOT / "build/img2_weapons_t13"
    out.mkdir(parents=True, exist_ok=True)
    (out / "queue.json").write_text(json.dumps(q, ensure_ascii=False), encoding="utf-8")
    print(len(q), max(len(x["prompt"]) for x in q))


if __name__ == "__main__":
    main()
