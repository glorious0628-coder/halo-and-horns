"""Writes art/prompts/HornsProp_<Name>_front.txt (+ queue json build/img2_halo_mv/horns_fronts.json) for the Horns town props (High).
Multiview buildings get a straight front view (back/left/right follow with the front as reference); small props get a three-quarter view.
Style references are crops of art/review/s2/place_HornsTown_sheet.jpg (whole, hp1 gate, h2 tower, h3 camp, h4 fence/wall, h5 bridge).
Run: py tools/_horns_prop_prompts.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art" / "prompts"

HEAD = "Use the attached image only as a style reference. Draw only this one object, as a standalone prop, "
TAIL = (
    " Isolated game prop for a kids fantasy war-camp town: dark purple basalt stone, rough brown wood with rope bindings, red cloth, "
    "ivory horns and spikes, iron lanterns, warm orange lava glow, glossy chunky toy-like 3D render with soft rounded bevels, same style, colors and lighting as the attached reference. "
    "No faces, no skulls, no lettering or symbols, no people. Plain flat medium gray background, wide empty margin, shadowless, whole object in frame. "
    "Only soft round glows and sparks; no light rays, no beams, no sunburst."
)
STRAIGHT = " Straight front view, centered."
THREEQ = " Three-quarter front view, centered."

# name -> (ref key, view, description)
PROPS = {
    "Gate": ("hp1", STRAIGHT, "the big war camp gate: two square dark basalt gate pillars with a huge curved ivory horn on each top, a red banner with a plain horned-bull silhouette and an iron lantern hanging on each pillar, joined by a thick log lintel with ivory spikes along it, a stone brazier with flames at each foot, open passage between the pillars."),
    "WatchTower": ("h2", STRAIGHT, "a tall wooden watchtower: four thick log legs on stone feet, a wooden ladder up the front, a railed platform, a red cloth canopy roof with four curved ivory horns, a flaming torch on the top, a red banner with a plain horned-bull silhouette and an iron lantern."),
    "WarTent": ("h3", STRAIGHT, "a large red war tent: round red cloth canopy with scalloped edges on thick wooden poles, two big curved ivory horns and a pointed ivory finial on top, the front open with red curtains tied back, a red carpet in the doorway, iron lanterns on the poles."),
    "StallSmith": ("h3", STRAIGHT, "a smith market stall: a red cloth awning on four wooden posts, a wooden counter with a small iron anvil, hammers and tongs, a rack of plain swords and axes at the back, an iron lantern."),
    "StallPotion": ("h3", STRAIGHT, "a potion market stall: a red cloth awning on four wooden posts, a wooden counter with round glass bottles of red and orange potions on shelves, a small cauldron, an iron lantern."),
    "StallBread": ("h3", STRAIGHT, "a bakery market stall: a red cloth awning on four wooden posts, a wooden counter with loaves of bread, round buns and a basket, an iron lantern."),
    "StallJuice": ("h3", STRAIGHT, "a juice market stall: a red cloth awning on four wooden posts, a wooden counter with wooden barrels, clay jugs and orange and purple fruits in a crate, an iron lantern."),
    "HouseA": ("h3", STRAIGHT, "a wide log-and-stone house: a dark basalt base, thick log walls with rope bindings, a steep red cloth-tiled roof with a curved ivory horn at each end of the ridge, a big double wooden door with iron bands, two small glowing windows, iron lanterns."),
    "HouseB": ("h2", STRAIGHT, "a two-story tower house: a dark basalt ground floor, a log upper floor with a small railed balcony, a pointed red roof with four small ivory horns at the corners, a ladder to the balcony, glowing windows, a red banner and an iron lantern."),
    "StoneBridge": ("h5", STRAIGHT, "a dark basalt stone arch bridge seen from the side: one big arch underneath, a cobblestone deck, wooden railings with ivory spikes, a square stone post with an iron lantern and a small red banner at each end."),
    "Bonfire": ("h3", THREEQ, "a camp bonfire: a ring of round grey stones, stacked logs with tall orange flames and sparks, and six short log stools around it."),
    "SpikeFence": ("h4", THREEQ, "one short section of spike fence: four thick wooden stakes with ivory spike tips and red rope bands, joined by two horizontal log rails."),
    "Brazier": ("h4", THREEQ, "one stone brazier: a square dark basalt base with an iron bowl on top holding orange flames."),
    "Lantern": ("h4", THREEQ, "one tall wooden lantern post with an iron hanging lantern glowing warm orange."),
    "BannerPole": ("h4", THREEQ, "one tall wooden banner pole with a red cloth banner with a plain horned-bull silhouette and a curved ivory horn on the top."),
    "Pine": ("whole", THREEQ, "one dark green pointed pine tree with a wide red cloth band around the trunk."),
    "RockColumnA": ("whole", THREEQ, "one large cluster of purple basalt rock columns with rounded tops, thin orange lava glow in the cracks."),
    "RockColumnB": ("whole", THREEQ, "one medium purple basalt rock column group, three columns of different heights with rounded tops, thin orange lava glow in the cracks."),
    "RockColumnC": ("whole", THREEQ, "one small low purple basalt rock pile with rounded tops, thin orange lava glow in the cracks."),
    "Crate": ("h3", THREEQ, "one wooden crate with iron corners and one small wooden crate on top."),
    "Barrel": ("h3", THREEQ, "one wooden barrel with iron hoops."),
    "Table": ("h3", THREEQ, "one rough wooden table with two wooden benches."),
}

REF_URLS = {
    "whole": "https://at.adobe.com/5fLFpG1dvh3ACbsc",
    "hp1": "https://at.adobe.com/5u9iWCzyZ2MXGL6W",
    "h2": "https://at.adobe.com/3Kbb5grAmRl0U9GY",
    "h3": "https://at.adobe.com/JPkhtf6bSWuUnwVp",
    "h4": "https://at.adobe.com/3DDeIr5PKFH2Sy6F",
    "h5": "https://at.adobe.com/GCVVEQdvlYBaCyGO",
}


def main() -> None:
    q = []
    for name, (ref, view, what) in PROPS.items():
        body = HEAD + what + view + TAIL
        assert len(body) < 1000, (name, len(body))
        (OUT / f"HornsProp_{name}_front.txt").write_text(
            f"[reference: HornsTown sheet crop '{ref}', High]\n{body}\n", encoding="utf-8")
        q.append({"key": f"{name}_front", "ref": REF_URLS[ref], "prompt": body, "multiview": view is STRAIGHT})
    (ROOT / "build/img2_halo_mv/horns_fronts.json").write_text(json.dumps(q, ensure_ascii=False, indent=1), encoding="utf-8")
    print(len(q), "prompts; max", max(len(x["prompt"]) for x in q))


if __name__ == "__main__":
    main()
