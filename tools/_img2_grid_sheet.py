"""Grid contact sheet: py tools/_img2_grid_sheet.py <out.jpg> <dir> <cols> <w> <h> <glob>
Files sorted by name; each cell is resized to w x h (aspect kept, letterboxed)."""
import sys
from pathlib import Path
from PIL import Image
R = Path(__file__).resolve().parent.parent
out = R / "art/review/s2" / sys.argv[1]
d = R / sys.argv[2]
cols, w, h = int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
fs = sorted(d.glob(sys.argv[6]))
rows = (len(fs) + cols - 1) // cols
S = Image.new("RGB", (cols * w, rows * h), (110, 110, 110))
for i, f in enumerate(fs):
    im = Image.open(f).convert("RGB")
    im.thumbnail((w, h), Image.LANCZOS)
    S.paste(im, ((i % cols) * w + (w - im.width) // 2, (i // cols) * h + (h - im.height) // 2))
S.save(out, quality=88)
print(out, len(fs))
