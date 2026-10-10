"""Horns props redo v2 (검수 10/10): plain props without the all-prop horns/lanterns/red-cloth tail.
Writes art/prompts/HornsProp_<Name>_v2_front.txt + build/img2_halo_mv/horns_fix.json (refs filled from build/img2_halo_mv/refs4.json keys h2,h3,h4,h5).
Run: py tools/_horns_prop_fix.py"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEAD = "Use the attached image only as a style reference. Draw only this one object, as a standalone prop, "
BASE = (" Isolated game prop for a kids fantasy war-camp town, glossy chunky toy-like 3D render with soft rounded bevels, same style and lighting as the reference. "
        "Plain flat medium gray background, wide empty margin, shadowless, whole object in frame. No faces, no skulls, no lettering, no people. No light rays, no beams, no sunburst.")
TQ = " Three-quarter front view, centered."
ST = " Straight front view, centered."

P = {
    "Crate": ("h3", TQ, "one plain rough wooden crate with dark iron band straps and iron corners, and one small plain wooden crate on top of it. Plain brown wood grain and iron only: no horns, no lantern, no red cloth, no glow."),
    "Barrel": ("h3", TQ, "one plain rough wooden barrel with dark iron hoops, visible wood-plank grain and a flat lid. Plain brown wood and iron only: no horns, no lantern, no red cloth, no glow."),
    "HouseB": ("h3", ST, "a small cozy cottage: single story, dark basalt stone lower walls with rough logs above, a low sloped wooden-plank roof in dark brown with a stone chimney, a plain wooden door with iron bands, one small round window, a woodpile and a barrel by the wall. No tower, no balcony, no ladder, no horns on the roof, no torch."),
    "StoneBridge": ("h5", ST, "a dark basalt stone arch bridge seen from the side: one arch underneath, a cobblestone deck, plain wooden railings, square stone posts at each end. All stone joints are plain dark grey-purple, with no glow on the bridge; a soft orange lava glow only on the ground below the arch."),
    "SpikeFence": ("h4", TQ, "one straight section of spike fence: four identical thick wooden stakes each topped with an identical straight ivory cone spike, red rope bands, joined by two horizontal log rails; only the left end has one thicker post, the right end is open so sections can be placed end to end."),
    "Table": ("h3", TQ, "one rough wooden table with two plain wooden benches, one small iron lantern standing on the table, nothing else: no horns, no red cloth, no pillars."),
    "Bonfire": ("h3", TQ, "an unlit camp fire pit: a ring of round grey stones around a neat stack of dark logs, and six short log stools around it. No flames, no sparks, no fire, no smoke, no glow."),
    "BannerPole": ("h4", TQ, "one tall dark wooden pole with a crossbar holding a rectangular red cloth banner that shows a golden horned bull head emblem on the red background, the bull has one pair of curved ivory horns, a plain iron finial on top of the pole."),
}


def main():
    refs = json.loads((ROOT / "build/img2_halo_mv/refs4.json").read_text(encoding="utf-8"))
    q = []
    for k, (ref, view, d) in P.items():
        body = HEAD + d + view + BASE
        assert len(body) < 1000, (k, len(body))
        (ROOT / "art/prompts" / f"HornsProp_{k}_v2_front.txt").write_text(f"[reference: HornsTown sheet crop '{ref}', High]\n{body}\n", encoding="utf-8")
        q.append({"key": k + "_v2", "ref": refs[ref], "prompt": body, "quality": "high"})
    (ROOT / "build/img2_halo_mv/horns_fix.json").write_text(json.dumps(q, ensure_ascii=False), encoding="utf-8")
    print(len(q), max(len(x["prompt"]) for x in q))


if __name__ == "__main__":
    main()
