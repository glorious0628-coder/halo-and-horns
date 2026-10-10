"""Halo town 'reason' props (A23-117), front views. Writes art/prompts/HaloReason_<Name>_front.txt and build/img2_halo_mv/halo_reason.json (ref filled by caller).
Run: py tools/_halo_reason_props.py"""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
HEAD = "Use the attached image only as a style reference. Draw only this one object, as a standalone prop: "
TAIL = (" Three-quarter front view, centered. White marble with gold trim, warm light wood and pale sky-blue accents, glossy chunky toy-like 3D render with soft rounded bevels, same style, colors and lighting as the attached reference. "
        "No lettering, no numbers, no symbols, no faces, no people. Plain flat medium gray background, wide empty margin, shadowless, whole object in frame. Only soft round glows; no light rays, no beams, no sunburst.")
P = {
 "BenchA": "a town bench with a round-topped curved backrest: a white marble seat slab with gold edge bands on two chunky marble legs, a light wooden slat seat, and a curved white marble backrest with a thin gold rim.",
 "BenchB": "a flat town bench with a built-in planter: a white marble seat with light wooden slats and gold bands, and a small marble flower box attached at one end full of round green leaves and little white and blue flowers.",
 "BenchC": "a plain long town bench: a light wooden slat seat on two white marble side blocks with gold bands, no backrest, a small gold ball on each side block.",
 "BreadStand": "a bakery display stand for in front of a shop: a low white marble counter with gold trim, a light wood top shelf and wicker baskets full of golden round loaves, baguettes and rolls, a small blue-and-white striped cloth hanging on the front.",
 "FruitStall": "a market fruit crate stall: a light wooden stand with a small blue-and-white striped canopy, wooden crates full of oranges, green apples, red apples and blueberries, a gold trim on the corners.",
 "FlowerCart": "a flower cart: a light wooden two-wheel hand cart with gold hub caps and a long handle, filled with buckets and bunches of white, blue and yellow flowers and green leaves, a small blue-and-white striped canopy.",
 "PotionCrate": "a potion crate display with a small blank sign: a light wooden crate with gold corners holding round glass bottles of pale blue, pink and green liquids with cork stoppers, beside it a short white marble post holding a small empty blank gold-rimmed board with nothing painted on it.",
 "Scarecrow": "a training straw dummy on a stand, a faceless round burlap sack head with simple stitched seams only, a body of tied straw bundles in a tidy tunic, a wooden post and a crossbar for arms, a round base block of white marble.",
 "RackShieldSword": "a training-yard weapon rack: a light wooden frame with gold fittings holding two round shields in blue and white with gold rims and three wooden practice swords with round tips.",
 "Clothesline": "a tidy clothesline between two short white marble posts with gold caps: a thin rope holding plain white and pale-blue cloth towels and small plain cloths hanging neatly, a small wooden basket of folded cloths at the foot of one post, nothing but towels and cloths.",
 "VegGarden": "a small tidy vegetable garden bed with a low white marble border: rows of cabbages, carrots with leafy tops, tomatoes on small wooden stakes, and a gold-rimmed light blue watering can standing at the corner.",
 "Woodpile": "a neat woodpile: stacked round-cut logs in light wood with warm round end faces, a small white marble roof-shaped cover with gold trim on top, and a small axe-free wooden log base.",
 "PhotoDisc": "a photo-spot gold disc standing upright on two small white marble feet: a big round gold plate with a thick rim, decorated with soft round embossed circle patterns, plain, no writing, no rays, no spikes, with a low white marble step in front.",
 "GuardPost": "a town-gate guard post: a small white marble booth with a gold roof cap and a light wooden counter window, beside it a freestanding white marble notice board with a gold frame, the notice board completely empty and blank.",
}
def main():
    q = []
    for k, d in P.items():
        body = HEAD + d + TAIL
        assert len(body) < 1000, (k, len(body))
        (ROOT / "art/prompts" / f"HaloReason_{k}_front.txt").write_text(f"[reference: HaloProp_Shop_front (style), Medium x2 then High]\n{body}\n", encoding="utf-8")
        for s in "AB":
            q.append({"key": f"HR_{k}_{s}", "prompt": body, "quality": "medium"})
    (ROOT / "build/img2_halo_mv/halo_reason.json").write_text(json.dumps(q, ensure_ascii=False), encoding="utf-8")
    print(len(q), max(len(x["prompt"]) for x in q))
main()
