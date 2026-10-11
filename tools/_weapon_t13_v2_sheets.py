"""Contact sheets for weapon T1~T3 v2 -> art/review/s2/weapons_t13v2_{warrior,mage,archer,neutral,berserker_final}.jpg"""
from pathlib import Path
from PIL import Image, ImageDraw
R = Path(__file__).resolve().parent.parent
SRC = R / "art/out/s2/weapons_t13_v2"
OUT = R / "art/review/s2"
G = {
 "warrior": ["Halo_Paladin", "Horns_Berserker"],
 "mage": ["Halo_LightMage", "Horns_DarkMage"],
 "archer": ["Halo_Ranger", "Horns_ShadowHunter"],
 "neutral": ["Neutral_Blacksmith", "Neutral_Alchemist", "Neutral_PetTamer"],
}
W = 512
def cell(path, label):
    im = Image.open(path).convert("RGB").resize((W, W), Image.LANCZOS)
    ImageDraw.Draw(im).text((8, 6), label, fill=(255, 255, 255))
    return im
def sheet(rows, name):
    s = Image.new("RGB", (W * 3, W * len(rows)), (110, 110, 110))
    for r, row in enumerate(rows):
        for c, (p, l) in enumerate(row):
            s.paste(cell(p, l), (c * W, r * W))
    s.save(OUT / name, quality=88)
for k, cls in G.items():
    sheet([[(SRC / f"Weapon_{c}_T{t}_v2.png", f"{c} T{t}") for t in (1, 2, 3)] for c in cls], f"weapons_t13v2_{k}.jpg")
sheet([[(SRC / f"Weapon_Horns_Berserker_final_{x}.png", f"Berserker final {x}") for x in "abc"]], "weapons_t13v2_berserker_final.jpg")
