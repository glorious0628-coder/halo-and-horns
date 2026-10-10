"""Horns castle / gate PARTS (A23-107, sharpness_redo_list: castle = 본관/탑 L·R 따로/성벽 조각/성문 문틀+징 박은 문짝/앞 계단/뿔 장식; gate = 왼·오른 기둥 따로 + 통나무 상인방; flat banner + bull emblem).
Writes art/prompts/HornsPart_<Name>_front.txt and build/img2_halo_mv/horns_parts_fronts.json (refs from build/img2_halo_mv/refs5.json keys castle, gate).
Run: py tools/_horns_parts_prompts.py"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEAD = "Style and color reference only. Draw only this one separate part, standalone: "
TAIL = (" Straight front view, centered, whole piece in frame with wide margin, plain flat gray background, no ground, no other parts. "
        "Glossy chunky toy-like 3D render: dark purple-grey basalt blocks with joint lines, brown wood-grain logs with rope bindings, dark iron bands, ivory cone spikes; dense carving, no bare flat walls. "
        "NO banners, flags, cloth, lanterns, flames, fire, skulls, lettering, faces, people, light rays.")
TAIL_FLAT = (" Shown flat and straight on, centered, whole piece in frame with wide margin, plain flat gray background. Glossy chunky toy-like 3D render, clearly different materials. "
             "No lettering, no faces, no skulls, no people, no light rays.")

P = {
    "CastleKeep": ("castle", TAIL, "the main keep hall of a war-camp castle: a wide dark basalt rectangular hall with thick log beams and rope bindings, a flat roof deck with stone battlements and a row of ivory cone spikes, small arrow-slit windows, a big empty arched doorway at the front center with no door, plain flat top and bottom joint faces, no towers, no stairs."),
    "CastleTowerL": ("castle", TAIL, "the left corner tower of the castle: a tall square dark basalt tower with log beams and rope bands near the top, stone battlements with ivory cone spikes, narrow arrow-slit windows, a plain flat bottom."),
    "CastleTowerR": ("castle", TAIL, "the right corner tower of the castle, its own piece, clearly different from the left tower: a tall round-cornered basalt tower thicker at the base, log bands at different heights, different slit windows, stone battlements with ivory cone spikes, a plain flat bottom."),
    "CastleWallA": ("castle", TAIL, "a straight castle wall section: dark basalt blocks with a walkway on top, stone battlements, thick log posts with rope at both ends, plain flat joint faces on the left and right sides."),
    "CastleWallB": ("castle", TAIL, "another straight castle wall section, its own piece with two arrow-slit windows and a stepped top edge: dark basalt blocks, stone battlements, log posts with rope at both ends, plain flat joint faces on the left and right sides."),
    "CastleGateFrame": ("castle", TAIL, "the castle gate frame: a deep dark basalt arch with thick wooden beams and iron bands around an empty opening, standing on the ground, big enough for people to walk through, nothing hanging on it."),
    "CastleStairs": ("castle", TAIL, "the front stairs of the castle: wide dark basalt steps on a stone platform with low stone side walls topped by ivory cone spike posts, plain flat top."),
    "CastleHornL": ("castle", TAIL, "one large curved ivory horn ornament on a short dark stone mount block with a rope band, the horn curving to the right, plain flat bottom on the mount."),
    "CastleHornR": ("castle", TAIL, "one large curved ivory horn ornament on a short dark stone mount block with a rope band, the horn curving to the left, its own piece, plain flat bottom on the mount."),
    "GatePillarL": ("gate", TAIL, "the left pillar of the war camp gate: a square dark basalt pillar on a rocky base with a thick log leg beside it bound with rope, a notch near the top on the right side where a lintel log fits, a plain flat top with one ivory cone spike."),
    "GatePillarR": ("gate", TAIL, "the right pillar of the war camp gate, its own piece with a different stone block layout: a square dark basalt pillar on a rocky base with a thick log leg beside it bound with rope, a notch near the top on the left side where a lintel log fits, a plain flat top with one ivory cone spike."),
    "GateLintel": ("gate", TAIL, "the lintel of the war camp gate: one thick horizontal brown log with rope-bound ends, iron bands and a row of five ivory cone spikes along its top, seen straight from the front."),
    "CastleDoorLeafL": ("castle", TAIL_FLAT, "one tall wooden gate door leaf, left leaf: dark red-brown wood planks with heavy dark iron straps, rows of round iron studs and a big iron ring handle."),
    "CastleDoorLeafR": ("castle", TAIL_FLAT, "one tall wooden gate door leaf, right leaf, its own piece with different strap positions: dark red-brown wood planks with heavy dark iron straps, rows of round iron studs and a big iron ring handle."),
    "BannerRed": ("castle", TAIL_FLAT, "one rectangular red cloth banner with a gold border and a swallowtail bottom edge, plain red with no emblem, hanging straight with a thin dark wood rod at the top."),
    "BannerBull": ("castle", TAIL_FLAT, "one rectangular red cloth banner with a gold border and a swallowtail bottom edge, a golden horned bull head emblem in the middle (one pair of curved ivory horns), hanging straight with a thin dark wood rod at the top."),
    "ShieldBull": ("castle", TAIL_FLAT, "one round wooden shield with a dark iron rim and iron studs, a golden horned bull head emblem painted on the red face, one pair of curved horns."),
}


def main():
    refs = json.loads((ROOT / "build/img2_halo_mv/refs5.json").read_text(encoding="utf-8"))
    q = []
    for k, (ref, tail, d) in P.items():
        body = HEAD + d + tail
        assert len(body) < 1000, (k, len(body))
        (ROOT / "art/prompts" / f"HornsPart_{k}_front.txt").write_text(f"[reference: Horns {ref} front, High]\n{body}\n", encoding="utf-8")
        q.append({"key": "HP_" + k, "ref": refs[ref], "prompt": body, "quality": "high"})
    (ROOT / "build/img2_halo_mv/horns_parts_fronts.json").write_text(json.dumps(q, ensure_ascii=False), encoding="utf-8")
    print(len(q), max(len(x["prompt"]) for x in q))


if __name__ == "__main__":
    main()
