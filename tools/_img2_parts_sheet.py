"""Contact sheet of Halo parts: py tools/_img2_parts_sheet.py <out.jpg> <name> [name...]  (front, back, left, right per name, one row each)"""
import sys
from pathlib import Path
from PIL import Image
R = Path(__file__).resolve().parent.parent
D = R / "art/out/s2/halo/parts"
out = R / "art/review/s2" / sys.argv[1]
names = sys.argv[2:]
sz = 300
S = Image.new("RGB", (4 * sz, len(names) * sz), (110, 110, 110))
for r, n in enumerate(names):
    for c, v in enumerate(("front", "back", "left", "right")):
        f = D / f"HaloPart_{n}_{v}_HQ_src.png"
        if f.exists():
            S.paste(Image.open(f).convert("RGB").resize((sz, sz), Image.LANCZOS), (c * sz, r * sz))
S.save(out, quality=88)
print(out)
