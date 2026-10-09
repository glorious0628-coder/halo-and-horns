"""Writes art/prompts/HornsProp_<Name>_{back,left,right}.txt for the 10 Horns town buildings (multiview, High).
Each prompt takes the finished front image (art/out/s2/horns/HornsProp_<Name>_front_HQ_src.png) as the reference and only turns the camera.
Run: py tools/_horns_prop_mv_prompts.py   (also writes build/img2_halo_mv/horns_mv.json = [{key, name, prompt}])
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art" / "prompts"

TAIL = (
    " Whole object in frame with a wide empty margin, centered. Plain flat medium gray background, shadowless. "
    "Same glossy chunky toy-like 3D render, same colors and lighting. No faces, no skulls, no lettering or symbols, no people. "
    "Only soft round glows and sparks; no light rays, no beams, no sunburst."
)

# name -> (what, back note, side note)
PROPS = {
    "Gate": ("the big war camp gate with two square dark basalt pillars, huge curved ivory horns, red banners, iron lanterns, a log lintel with ivory spikes and stone braziers",
             "The back of the gate: the same pillars, horns and lintel, the banners hang on this side too, the lanterns and braziers the same.",
             "The side of one pillar: the narrow pillar profile with its curved ivory horn on top, the banner and lantern seen edge-on, the log lintel running away behind."),
    "WatchTower": ("a tall wooden watchtower with a ladder, a railed platform and a red canopy roof with four ivory horns",
                   "The back of the tower: the four log legs, the platform railing, the red canopy and horns, no ladder on this side, a banner hangs here.",
                   "The side of the tower: the ladder seen edge-on, the log legs and railed platform, the red canopy with horns, the torch on top."),
    "WarTent": ("a large red war tent with curved ivory horns, open red curtains, a red carpet and iron lanterns",
                "The back of the tent: smooth red cloth with scalloped edge, the wooden poles, the horns on top, no opening, no carpet.",
                "The side of the tent: the red cloth canopy sloping down on wooden poles, the horns on top, a lantern on a pole, the curtain edge at the front."),
    "StallSmith": ("a smith market stall with a red awning, wooden counter, small anvil, hammers and a rack of plain swords",
                   "The back of the stall: the four posts, the back of the red awning, the rack of plain swords and axes seen from behind, a wooden back rail.",
                   "The side of the stall: the red awning sloping, the end of the counter with the anvil, a post and an iron lantern."),
    "StallPotion": ("a potion market stall with a red awning, wooden counter, shelves of red and orange bottles and a small cauldron",
                    "The back of the stall: the four posts, the back of the red awning, the shelves of bottles seen from behind, a wooden back rail.",
                    "The side of the stall: the red awning sloping, the end of the counter with bottles, a post and an iron lantern."),
    "StallBread": ("a bakery market stall with a red awning, wooden counter, loaves of bread, buns and a basket",
                   "The back of the stall: the four posts, the back of the red awning, a wooden back rail and a shelf of loaves seen from behind.",
                   "The side of the stall: the red awning sloping, the end of the counter with a basket, a post and an iron lantern."),
    "StallJuice": ("a juice market stall with a red awning, wooden counter, barrels, clay jugs and a crate of fruit",
                   "The back of the stall: the four posts, the back of the red awning, barrels and jugs seen from behind, a wooden back rail.",
                   "The side of the stall: the red awning sloping, the end of the counter with a barrel, a post and an iron lantern."),
    "HouseA": ("a wide log-and-stone house with a steep red roof, ivory horns on the ridge ends, a double wooden door and glowing windows",
               "The back of the house: log wall on a basalt base, the steep red roof with horns at the ridge ends, two small glowing windows, no door.",
               "The side of the house: the log side wall, the steep red roof slope with a horn at the ridge end, one glowing window, an iron lantern."),
    "HouseB": ("a two-story tower house with a log upper floor, a small railed balcony, a pointed red roof with four small horns and a ladder",
               "The back of the house: basalt ground floor, log upper floor, a back window, the pointed red roof with four horns, no balcony, no ladder.",
               "The side of the house: the ladder up to the balcony seen edge-on, the log upper floor, the pointed red roof with horns, a glowing window."),
    "StoneBridge": ("a dark basalt stone arch bridge with one big arch, a cobblestone deck, wooden railings with ivory spikes and a lantern post with a red banner at each end",
                    "The other long side of the bridge: the same single arch under the deck, the railing with ivory spikes seen from outside, the posts at both ends.",
                    "The view from one end along the road: the cobblestone deck rising over the arch, railings with ivory spikes on both sides, the two lantern posts with red banners at this end."),
}

VIEWS = {
    "back": "straight view from directly behind",
    "left": "straight view from directly the left side (a 90-degree turn)",
    "right": "straight view from directly the right side (a 90-degree turn)",
}


def build(name: str, what: str, back: str, side: str, view: str) -> str:
    note = back if view == "back" else side
    mirrored = " This is the mirror side of the left view." if view == "right" and name != "StoneBridge" else ""
    if name == "StoneBridge" and view == "right":
        note = "The view from the other end along the road: the cobblestone deck coming down from the arch, railings with ivory spikes on both sides, the two lantern posts with red banners at this end."
    return (
        f"Redraw the attached reference object as the same object from another camera angle: {what}. "
        f"Keep the exact same size, proportions, colors, materials and every part in the same place; only the camera turns. "
        f"{VIEWS[view].capitalize()}. {note}{mirrored}" + TAIL
    )


def main() -> None:
    q = []
    for name, (what, back, side) in PROPS.items():
        for view in ("back", "left", "right"):
            body = build(name, what, back, side, view)
            assert len(body) < 1000, (name, view, len(body))
            (OUT / f"HornsProp_{name}_{view}.txt").write_text(
                f"[reference: art/out/s2/horns/HornsProp_{name}_front_HQ_src.png (the finished front view), High]\n{body}\n", encoding="utf-8")
            q.append({"key": f"{name}_{view}", "name": name, "prompt": body})
    (ROOT / "build/img2_halo_mv/horns_mv.json").write_text(json.dumps(q, ensure_ascii=False, indent=1), encoding="utf-8")
    print(len(q), "prompts; max", max(len(x["prompt"]) for x in q))


if __name__ == "__main__":
    main()
