"""Halo parts front redraws v2 (검수 10/10: no baked banners / halo rings, rose-window frame, gate towers not mirrored, material cues).
Writes art/prompts/HaloPart_<Name>_v2_front.txt and build/img2_halo_mv/halo_parts_fix.json (refs filled from build/img2_halo_mv/refs3.json).
Run: py tools/_halo_parts_fix.py"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEAD = "Style and color reference only. Draw only this one separate part, standalone: "
TAIL = (" Straight front view, centered, whole piece in frame with wide margin, plain flat gray background, no ground, no other parts. "
        "Glossy chunky toy-like 3D render: bright yellow polished gold with white highlights, white marble with joint lines, pale sky-blue glass; dense trim, no bare flat walls. "
        "NO banners, flags, cloth, floating halo ring, lettering, faces, people, light rays.")

P = {
    "CathBody": ("cathedral", "the main hall body of the cathedral: a wide white marble rectangular hall with a flat roof deck, rows of tall arched window openings with gold frames (empty recesses, no glass), thin gold bands, carved pilasters, a tall empty arched entrance opening at the front center with no door, and above the entrance one big round rose-window recess with a thick empty gold frame (nothing inside it), plain flat top and bottom joint faces, no dome, no towers, no stairs, only small gold hook brackets under the roof edge."),
    "CathTowerA": ("cathedral", "a slim corner tower of the cathedral: a tall slim round white marble tower with gold bands, carved ring ledges, small arched windows with gold frames, a small gold dome roof with a short gold finial ball on top, a plain flat underside."),
    "CathTowerB": ("cathedral", "the other slim corner tower of the cathedral, its own piece with different band heights and window spacing, slightly wider at the base: a tall round white marble tower with gold bands, carved ring ledges, small arched windows with gold frames, a small gold dome roof with a short gold finial ball on top, a plain flat underside."),
    "CathDome": ("cathedral", "the large central gold dome of the cathedral: a glossy bright gold dome with thin raised gold ribs and a small round gold lantern with a gold ball on top, standing on a short round white marble drum with small gold-framed arched window openings, a plain flat circular underside."),
    "TowerDome": ("tower", "the dome of the slim tower: a glossy bright gold dome with a slim spire ending in a small gold ball, on a small round gold base ring with a plain flat circular underside."),
    "TowerDoorFrame": ("tower", "the door frame of the slim tower: a tall arched white marble frame with thick gold trim, carved side pilasters with gold capitals, a deep reveal, standing on the ground, tall enough for people, nothing hanging on it."),
    "GateLantern": ("gate", "one tall slim white marble lantern post with a glossy gold lantern with glowing warm glass and a gold ball on top, a square marble base with gold bands and carved panels, a plain smooth post shaft."),
    "GateTowerR": ("gate", "the RIGHT tower body of the town gate, designed clearly different from the left tower: a round white marble cylinder tower with three tall narrow gold-framed arched slit windows stacked on one side, one wide gold band near the bottom and two thin gold bands near the top, a plain flat top with no dome, a plain flat vertical joint strip on its left side, no wall, no stairs."),
}


def main():
    refs = json.loads((ROOT / "build/img2_halo_mv/refs3.json").read_text(encoding="utf-8"))
    q = []
    for k, (ref, d) in P.items():
        body = HEAD + d + TAIL
        assert len(body) < 1000, (k, len(body))
        (ROOT / "art/prompts" / f"HaloPart_{k}_v2_front.txt").write_text(f"[reference: Halo {ref} front (style/shape), High]\n{body}\n", encoding="utf-8")
        q.append({"key": k + "_v2", "ref": refs[ref], "prompt": body, "quality": "high"})
    (ROOT / "build/img2_halo_mv/halo_parts_fix.json").write_text(json.dumps(q, ensure_ascii=False), encoding="utf-8")
    print(len(q), max(len(x["prompt"]) for x in q))


main()
