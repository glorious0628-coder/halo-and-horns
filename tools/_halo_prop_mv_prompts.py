"""Writes art/prompts/HaloProp_<Name>_{back,left,right}.txt for the 9 Halo town buildings (multiview, High).

Each prompt takes the finished front image as its reference (art/out/s2/halo/<Name>_front_HQ_src.png) and only turns the camera.
Run: py tools/_halo_prop_mv_prompts.py
"""
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "art" / "prompts"

TAIL = (
    " Whole object in frame with a wide empty margin, centered. Plain flat medium gray background, shadowless. "
    "Same glossy chunky toy-like 3D render, same colors and lighting. No clouds under it, no faces, "
    "no lettering or symbols, no people. Only soft round glows; no light rays, no beams, no sunburst."
)

# name -> (what it is, back note, side note)
PROPS = {
    "Gate": (
        "the grand town gate with two round white towers, golden domes, a gold-trimmed open arch and a halo ring above",
        "The back of the gate: the same two towers and arch, the shield emblem is a plain smooth gold disc, both banners hang on this side too, paved road under the arch.",
        "The side of one tower: a slim round tower profile with small arched windows, the arch wall and banner seen edge-on, the other tower hidden behind.",
    ),
    "Tower": (
        "one slim tall round white tower with a golden dome and a floating golden halo ring above it",
        "The back of the tower: plain white wall with the same small arched windows, no banner on this side, gold bands and the dome the same.",
        "The side of the tower: the long pale sky-blue banner seen along its edge hanging down, small arched windows, gold bands.",
    ),
    "Cathedral": (
        "the grand cathedral with a large gold-striped dome, side wings and slim side towers",
        "The back of the cathedral: plain white back wall with rows of sky-blue arched windows, the same dome and side towers, no door and no stairs.",
        "The side of the cathedral: the long side wall with sky-blue arched windows, the dome rising in the middle, one side tower, gold bands.",
    ),
    "DomeHouseA": (
        "a small round white house with a golden dome and arched windows",
        "The back of the house: smooth round white wall with two arched windows, no door, no flower pot.",
        "The side of the house: round white wall with one arched window, the golden dome on top, the flower pot just visible at the edge.",
    ),
    "DomeHouseB": (
        "a square two-story white house with a small golden dome, gold bands and a white balustrade balcony",
        "The back of the house: plain white wall with arched windows on both floors, a small back balcony, gold bands, the same dome.",
        "The side of the house: plain white side wall with two arched windows and gold bands, the balcony edge seen from the side, the dome on top.",
    ),
    "Shop": (
        "a small round-roofed white shop with a golden dome and a sky-blue and white striped awning over a counter",
        "The back of the shop: plain white round wall with a small arched window and a back door, the back of the striped awning edge, the dome.",
        "The side of the shop: round white wall, the striped awning seen from the side sloping out, the end of the counter and a crate, the dome.",
    ),
    "Statue": (
        "a white marble knight statue in full armor with a spear and a round shield, on a round base and a square pedestal",
        "The back of the statue: the back of the helmet with no face, armor plates from behind, the spear and the inside of the shield, the same base and pedestal.",
        "The side of the statue: knight profile with a closed helmet and no face, the spear held upright, the shield edge-on, the same base and pedestal.",
    ),
    "ArchBridge": (
        "an arched white stone bridge with one arch, white balustrade with gold-ball posts and gold lantern posts at both ends",
        "The other long side of the bridge: the same single arch under the span, balustrade with gold-ball posts seen from outside.",
        "The view from one end along the road: the tiled road rising over the arch, balustrade on both sides, the two gold lantern posts at this end.",
    ),
}

VIEWS = {
    "back": "straight view from directly behind",
    "left": "straight view from directly the left side (a 90-degree turn)",
    "right": "straight view from directly the right side (a 90-degree turn)",
}


def build(name: str, what: str, back: str, side: str, view: str) -> str:
    note = back if view == "back" else side
    mirrored = " This is the mirror side of the left view." if view == "right" and name != "ArchBridge" else ""
    if name == "ArchBridge" and view == "right":
        note = "The view from the other end along the road: the tiled road coming down from the arch, balustrade on both sides, the two gold lantern posts at this end."
    if name == "ArchBridge" and view == "left":
        note = side
    head = f"[reference: art/out/s2/halo/HaloProp_{name}_front_HQ_src.png (the finished front view), High]\n"
    body = (
        f"Redraw the attached reference object as the same object from another camera angle: {what}. "
        f"Keep the exact same size, proportions, colors, materials and every part in the same place; only the camera turns. "
        f"{VIEWS[view].capitalize()}. {note}{mirrored}"
    )
    return head + body + TAIL + "\n"


def main() -> None:
    n = 0
    for name, (what, back, side) in PROPS.items():
        for view in ("back", "left", "right"):
            text = build(name, what, back, side, view)
            body = text.split("\n", 1)[1]
            assert len(body) < 1000, (name, view, len(body))
            (OUT / f"HaloProp_{name}_{view}.txt").write_text(text, encoding="utf-8")
            n += 1
    print("wrote", n, "prompts")


if __name__ == "__main__":
    main()
