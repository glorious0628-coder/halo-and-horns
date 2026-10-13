"""Sheet for seethru.py: 14 views (level / from above / from below x front,right,back,left + top, bottom),
magenta = world behind, bright green = see-through spot inside the body (Roblox one-sided).
py tools/design_review/seethru_sheet.py <render_dir> <label> ... -> <render_dir>/<label>__seethru.jpg
"""
import os
import sys

from PIL import Image, ImageDraw

rd = sys.argv[1]
C, HDR = 300, 22
ROWS = [("level", "s"), ("from above", "u"), ("from below", "d")]
for lab in sys.argv[2:]:
    o = Image.new("RGB", (C * 5, (C + HDR) * 3), (28, 28, 30))
    dr = ImageDraw.Draw(o)
    for r, (name, p) in enumerate(ROWS):
        y = r * (C + HDR)
        dr.text((4, y + 4), f"{lab}  {name}: front | right | back | left" + ("  | top / bottom" if r < 2 else ""), fill=(255, 220, 0))
        keys = [f"{p}{az}" for az in (0, 90, 180, 270)] + ([("top", "bot")[r]] if r < 2 else [])
        for k, key in enumerate(keys):
            f = os.path.join(rd, f"{lab}__hole_{key}.png")
            if os.path.exists(f):
                im = Image.open(f).convert("RGB")
                g = sum(1 for q in im.getdata() if q[1] > 200 and q[0] < 40 and q[2] < 100)
                o.paste(im.resize((C, C)), (k * C, y + HDR))
                dr.text((k * C + 4, y + HDR + 4), f"{key} green={g}", fill=(255, 255, 255) if g == 0 else (0, 255, 80))
    o.save(os.path.join(rd, f"{lab}__seethru.jpg"), quality=90)
    print("SHEET", lab)
