"""Assemble tools/weapon_fit_check.py tiles: grey background, red line = grip point (origin), ticks every stud.
  py tools/weapon_fit_check_sheet.py <out.png>   (reads <out>_tiles.txt, deletes the tile PNGs)
"""
import os
import sys

from PIL import Image, ImageDraw

out = sys.argv[1]
PX, Z0, Z1 = 90, -2.2, 4.5
rows = [l.split("|") for l in open(out[:-4] + "_tiles.txt").read().splitlines()]
tw, th = int(PX * 2.0), int(PX * (Z1 - Z0))
sheet = Image.new("RGB", (len(rows) * (tw + 10) + 40, th + 40), (104, 104, 104))
dr = ImageDraw.Draw(sheet)
y0 = lambda z: 30 + int((Z1 - z) * PX)
for z in range(-2, 5):
    dr.line((0, y0(z), sheet.width, y0(z)), fill=(140, 140, 140))
    dr.text((2, y0(z) - 12), f"{z}", fill="white")
for i, (p, lab, size) in enumerate(rows):
    im = Image.open(p).convert("RGBA")
    x = 40 + i * (tw + 10)
    sheet.paste(im, (x, 30), im)
    dr.text((x, 2), lab.replace("Weapon_Halo_", "").replace("_HD_fit", ""), fill="white")
    dr.text((x, 14), "size " + size, fill="white")
    os.remove(p)
dr.line((0, y0(0), sheet.width, y0(0)), fill=(255, 0, 0), width=2)
sheet.save(out)
os.remove(out[:-4] + "_tiles.txt")
print("saved", out)
