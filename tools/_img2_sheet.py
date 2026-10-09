"""Contact sheet of a Halo prop set: front + back/left/right. py tools/_img2_sheet.py Gate [Tower ...] -> art/review/s2/halo_mv_<name>.jpg"""
import sys
from pathlib import Path
from PIL import Image
R = Path(__file__).resolve().parent.parent
D = R / "art/out/s2/halo"
for n in sys.argv[1:]:
    s = Image.new("RGB", (1536, 384), (110, 110, 110))
    for i, v in enumerate(("front", "back", "left", "right")):
        f = D / f"HaloProp_{n}_{v}_HQ_src.png"
        if f.exists():
            s.paste(Image.open(f).convert("RGB").resize((384, 384), Image.LANCZOS), (i * 384, 0))
    out = R / f"art/review/s2/halo_mv_{n}.jpg"
    s.save(out, quality=90)
    print(out)
