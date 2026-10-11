"""Weapon 4-view sheets (front | back | left | right) -> art/review/s2/weapons_4v_<group>.jpg. Usage: py tools/_weapon_4v_sheet.py <group> key1 key2 ..."""
import sys
from PIL import Image, ImageDraw
N = 'art/out/s2/weapons_t13_4v/Weapon_'
g, keys = sys.argv[1], sys.argv[2:]
W = 320
S = Image.new('RGB', (W * 4, W * len(keys)), (110, 110, 110))
for r, k in enumerate(keys):
    for c, v in enumerate(['front', 'back', 'left', 'right']):
        im = Image.open(f'{N}{k}_{v}.png').convert('RGB').resize((W, W), Image.LANCZOS)
        ImageDraw.Draw(im).text((4, 3), f'{k} {v}', fill=(255, 255, 255)); S.paste(im, (c * W, r * W))
S.save(f'art/review/s2/weapons_4v_{g}.jpg', quality=86)
