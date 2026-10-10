"""Halo town big-building PARTS (A23-107, docs/design/halo_parts_plan_2026-10-10.md).
Writes art/prompts/HaloPart_<Name>_front.txt and build/img2_halo_mv/halo_parts_fronts.json (front prompts)
+ halo_parts_views.json (back/left/right prompts). Every part is its own new drawing (no reuse; left/right
towers and domes are different pieces). Run: py tools/_halo_parts_prompts.py"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEAD = "Use the attached building only as the style, color and shape reference. Draw only this one separate construction part as a standalone piece: "
TAIL = (" Straight front view, almost orthographic, centered, the whole piece inside the frame with a wide empty margin, plain flat medium gray background, shadowless, "
        "no ground, no other parts. Glossy chunky toy-like 3D render with soft rounded bevels, white marble with gold trim and pale sky-blue accents, same colors and lighting as the attached reference. "
        "No faces, no lettering or symbols, no people. Only soft round glows; no light rays, no beams, no sunburst.")

# name: (ref key, description)
P = {
    "GateTowerL": ("gate", "the LEFT tower body of the town gate: a round white stone cylinder tower with a few small recessed arched window openings and thin gold bands, a plain flat top with no dome, a plain flat vertical joint strip on its right side, no banner, no halo, no wall, no stairs."),
    "GateTowerR": ("gate", "the RIGHT tower body of the town gate, drawn as its own piece with a slightly different stone-block pattern and window positions: a round white stone cylinder tower with a few small recessed arched window openings and thin gold bands, a plain flat top with no dome, a plain flat vertical joint strip on its left side, no banner, no halo, no wall, no stairs."),
    "GateDomeL": ("gate", "a golden dome for the left gate tower: a glossy gold dome with thin raised ribs and a tall slim gold spire on top, on a round gold base ring with a plain flat circular underside."),
    "GateDomeR": ("gate", "a golden dome for the right gate tower, its own piece with a slightly different rib pattern: a glossy gold dome with thin raised ribs and a tall slim gold spire with a small ball, on a round gold base ring with a plain flat circular underside."),
    "GateArch": ("gate", "the central arch wall of the town gate: a white stone wall block with a big tall open arched passage framed in gold trim, a paved road strip with gold lines under the arch, a flat top edge, plain flat joint faces on the left and right sides, no door leaves, no shield, no halo, no banner."),
    "GateDoorLeafL": ("gate", "one tall arched door leaf for the gate arch, left leaf: sky-blue painted wooden planks with a thin gold border, gold hinges and a gold ring handle, shown flat and straight on."),
    "GateDoorLeafR": ("gate", "one tall arched door leaf for the gate arch, right leaf, its own piece with slightly different plank lines: sky-blue painted wooden planks with a thin gold border, gold hinges and a gold ring handle, shown flat and straight on."),
    "GateLantern": ("gate", "one tall slim white stone lantern post with a golden lantern and a gold ball on top, a square stone base with gold bands."),
    "CathStairs": ("cathedral", "the front staircase and floor slab of the cathedral: a wide low white marble floor slab with a wide staircase of broad steps in front and low side walls with gold-ball posts, a plain flat top where the hall sits."),
    "CathBody": ("cathedral", "the main hall body of the cathedral: a wide white marble rectangular hall with a flat roof deck, rows of tall arched window openings (empty recesses, no glass), thin gold bands, a tall empty arched entrance opening at the front center with no door, plain flat top and bottom joint faces, no dome, no towers, no stairs."),
    "CathDome": ("cathedral", "the large central gold dome of the cathedral: a glossy gold dome with thin raised gold stripes and a small round lantern on top, standing on a short round white drum with small arched window openings, a plain flat circular underside."),
    "CathTowerA": ("cathedral", "a slim corner tower of the cathedral: a tall slim round white tower with gold bands, small arched windows, a small gold dome roof and a small floating gold halo ring above, a plain flat underside."),
    "CathTowerB": ("cathedral", "the other slim corner tower of the cathedral, its own piece with slightly different bands and window spacing: a tall slim round white tower with gold bands, small arched windows, a small gold dome roof and a small floating gold halo ring above, a plain flat underside."),
    "CathDoorFrame": ("cathedral", "the main entrance door frame of the cathedral: a deep arched white marble door frame with a thick gold-trimmed arch and a deep reveal (a real hollow opening you can walk through), standing on the ground, tall enough for people."),
    "CathDoorLeaf": ("cathedral", "one tall arched wooden door leaf of the cathedral entrance: warm wooden planks with gold bands, gold hinges and a gold ring handle, shown flat and straight on."),
    "CathWindow": ("cathedral", "one tall arched window glass panel of the cathedral: sky-blue glass with thin gold glazing bars inside a slim gold frame, softly glowing, flat and straight on."),
    "TowerBody": ("tower", "the body of the slim tall round white tower (three floors): thin gold bands, small recessed arched window openings, an open tall arched entrance opening at the ground with no door, a plain flat top, no dome, no halo, no banner."),
    "TowerDome": ("tower", "the dome of the slim tower: a glossy golden dome with a slim spire and a floating golden halo ring above it, on a small round gold base ring with a plain flat circular underside."),
    "TowerDoorFrame": ("tower", "the door frame of the slim tower: a tall arched white stone frame with gold trim and a deep reveal, standing on the ground, tall enough for people."),
    "TowerDoorLeaf": ("tower", "one tall arched wooden door leaf of the slim tower: brown planks with gold bands, gold hinges and a gold handle, shown flat and straight on."),
    "TowerWindow": ("tower", "one small arched window glass panel of the slim tower: sky-blue glass with thin gold glazing bars in a slim gold frame, softly glowing, flat and straight on."),
}
VIEWS = {
    "back": "Straight view from directly behind. Show the back of this same piece: plain back side, joint faces flat, same colors and parts.",
    "left": "Straight view from directly the left side (a 90-degree turn) of this same piece, same colors and parts.",
    "right": "Straight view from directly the right side (a 90-degree turn) of this same piece, same colors and parts. Mirror of the left view.",
}
VEND = (" Whole piece in frame with a wide empty margin, centered, plain flat medium gray background, shadowless, no ground, no other parts. "
        "Same glossy chunky toy-like 3D render, colors and lighting. No faces, no lettering or symbols, no people. No light rays, no beams, no sunburst.")


def main():
    fr, vw = [], []
    for k, (ref, d) in P.items():
        body = HEAD + d + TAIL
        assert len(body) < 1000, (k, len(body))
        (ROOT / "art/prompts" / f"HaloPart_{k}_front.txt").write_text(
            f"[reference: Halo {ref} front (style/shape), High]\n{body}\n", encoding="utf-8")
        fr.append({"key": k, "ref": ref, "prompt": body})
        short = d.split(":")[0]
        for v, note in VIEWS.items():
            vb = ("Redraw the attached piece as the same piece from another camera angle: " + short + ". Keep exactly the same size, proportions, colors "
                  "and every part in the same place; only the camera turns. " + note + VEND)
            assert len(vb) < 1000, (k, v, len(vb))
            vw.append({"key": f"{k}_{v}", "part": k, "prompt": vb})
    (ROOT / "build/img2_halo_mv/halo_parts_fronts.json").write_text(json.dumps(fr, ensure_ascii=False), encoding="utf-8")
    (ROOT / "build/img2_halo_mv/halo_parts_views.json").write_text(json.dumps(vw, ensure_ascii=False), encoding="utf-8")
    print(len(fr), "fronts;", len(vw), "views; max front", max(len(x["prompt"]) for x in fr))


main()
