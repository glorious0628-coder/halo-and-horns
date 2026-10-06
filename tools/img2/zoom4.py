"""4x zoom crops of an RGBA cutout on navy, magenta and white: zoom4.py <img> <out> x,y,w,h [x,y,w,h ...] (fractions)."""
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGBA")
W, H = im.size
rows = []
for spec in sys.argv[3:]:
    x, y, w, h = map(float, spec.split(","))
    box = (int(x * W), int(y * H), int((x + w) * W), int((y + h) * H))
    c = im.crop(box)
    c = c.resize((c.width * 4, c.height * 4), Image.NEAREST)
    tiles = []
    for col in [(20, 28, 60), (255, 0, 255), (250, 250, 250)]:
        t = Image.new("RGBA", c.size, col + (255,))
        t.alpha_composite(c)
        tiles.append(t)
    row = Image.new("RGB", (sum(t.width for t in tiles) + 16, c.height), (255, 255, 255))
    xx = 0
    for t in tiles:
        row.paste(t.convert("RGB"), (xx, 0)); xx += t.width + 8
    rows.append(row)
out = Image.new("RGB", (max(r.width for r in rows), sum(r.height for r in rows) + 8 * len(rows)), (255, 255, 255))
yy = 0
for r in rows:
    out.paste(r, (0, yy)); yy += r.height + 8
out.save(sys.argv[2])
print(out.size)
