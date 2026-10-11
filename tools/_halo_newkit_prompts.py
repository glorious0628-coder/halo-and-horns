"""Halo town 5th-stage NEW_ kits (docs/design/halo_new_prop_kits_2026-10-11.md): front-view Medium candidates (0 credits).
Style reference = finished HQ prop (HaloProp_Planter_front_HQ_src.png). Writes art/prompts/HaloKit_<Kit>_front[_x].txt and build/img2_halo_kits/queue.json
Run: py tools/_halo_newkit_prompts.py"""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
HEAD = "Use the attached image only as a rendering-style reference (glossy chunky toy-like 3D game prop, soft rounded bevels, same colors and lighting); do not copy its shape. Draw only this one object as a standalone prop, "
TAIL = (" Three-quarter front view, centered, whole object in frame with a wide empty margin, plain flat medium gray background, shadowless. "
        "Kids fantasy town palette: cream white marble, bright yellow polished gold, white, pale sky-blue. No faces or face-like marks, no people, no animals, no lettering or symbols, no light rays or beams.")
K = {
 "WhiteRock_a": "a rounded white marble-like boulder, smooth chunky shape with a few soft cracks and a little green moss on the base, about as wide as it is tall.",
 "WhiteRock_b": "a low wide rounded white boulder, cream white stone with soft ridges and a little green moss at the bottom.",
 "WhiteRock_c": "a small group of three rounded white rocks of different sizes sitting together, cream white stone, a little green moss.",
 "GatherBush": "a low round flowering bush with many small pale-pink and white flowers and a few small glowing golden berries that clearly sparkle as a gathering marker, neat leaf shapes between the flowers (not a plain lump), cream stone ring at the base.",
 "FlowerBush": "a low neat flowering bush, green leaves with clearly visible pale lavender and white flowers between the leaves, tidy rounded shape (not a cloud-like lump).",
 "CafeTable": "a small round cafe table: a thin white marble round top with a thin gold rim, one slim white pedestal leg on a round base. No chairs.",
 "CandleCrate": "a small wooden crate with a bundle of plain white candles standing in it (unlit, no flame), thin gold bands on the crate.",
 "Hedge_a": "a long low flowering garden hedge, dense green leaves with small white and pale-blue flowers, rounded ends, flat trimmed top.",
 "Hedge_b": "a shorter low flowering garden hedge, dense green leaves with small white flowers, rounded ends, trimmed top.",
 "WallLamp": "a small wall lamp: a slim iron bracket arm holding a glass lantern with a warm glowing light inside, small gold trim.",
 "ArmoryBarrels": "a group of two wooden barrels and one wooden crate stacked together, thin gold bands, pale wood, a small white cloth tied on one barrel.",
 "Beehive": "a white wooden beehive box: two stacked white wooden boxes with a small pitched roof and a small round entrance hole, thin gold trim. No bees.",
 "BellFrame": "a small wooden bell frame: two wooden posts with a crossbeam holding one small gold bell hanging in the middle, white cloth rope.",
 "BreadBasket": "a round woven wicker basket with a handle holding three or four fresh golden-brown round bread loaves, a white cloth peeking out.",
 "Cauldron": "a low round black iron cauldron on a stone ring base, filled with glowing pale-blue and green potion liquid, two small iron handles. No steam.",
 "Easel": "a wooden three-legged painter's easel holding a canvas with a simple painting of a calm blue sea and sky in flat color bands.",
 "NoticeBoard": "a wooden village notice board on two posts with a small pitched roof, the board is plain empty pale wood with no writing, thin gold trim.",
 "SteppingStones": "a row of five flat rounded white stepping stones laid in a gentle curve, thin, with a little green moss at the edges.",
 "Telescope": "a gold and wooden telescope on a three-legged wooden tripod, the long tube pointing up at the sky, gold rings.",
 "WaterBuckets": "two wooden water buckets with iron bands and rope handles, and one long wooden rake leaning against them.",
 "WateringCan": "a small golden watering can with a long spout and a round handle, a tiny pale-blue ribbon on the handle.",
}
def main():
    q = []
    for k, d in K.items():
        body = HEAD + d + TAIL
        assert len(body) < 1000, (k, len(body))
        (ROOT / "art/prompts" / f"HaloKit_{k}_front.txt").write_text(f"[reference: HaloProp_Planter_front_HQ (style only), Medium]\n{body}\n", encoding="utf-8")
        q.append({"key": f"HaloKit_{k}_front", "prompt": body, "quality": "medium"})
    out = ROOT / "build/img2_halo_kits"; out.mkdir(parents=True, exist_ok=True)
    (out / "queue.json").write_text(json.dumps(q, ensure_ascii=False, indent=1), encoding="utf-8")
    print(len(q), max(len(i["prompt"]) for i in q))
if __name__ == "__main__":
    main()
