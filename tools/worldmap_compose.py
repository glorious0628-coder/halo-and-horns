import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi
src = sys.argv[1]; dx = int(sys.argv[2]); dy = int(sys.argv[3]); out = sys.argv[4]
old = Image.open("art/ui/UIP_WorldMapV2.png").convert("RGB")      # 1024x683
cv = Image.new("RGB", (1041, 760))
cv.paste(old, (17, 77))
# strip above (y<77): flip of the old map's top rows; left margin: stretch column
top = old.crop((0, 0, 1024, 77)).transpose(Image.FLIP_TOP_BOTTOM)
cv.paste(top, (17, 0))
left = old.crop((0, 0, 1, 683)).resize((17, 683)); cv.paste(left, (0, 77))
cv.paste(top.crop((0, 0, 1, 77)).resize((17, 77)), (0, 0))
# wipe old island region with sea patch (from the old map's sea north of the middle island)
patch = old.crop((300, 5, 440, 135))
wipe = Image.new("RGB", (300, 250))
for x in range(0, wipe.width, 140):
    for y in range(0, wipe.height, 130):
        wipe.paste(patch, (x, y))
cv.paste(wipe, (0, 0))
g = Image.open(src).convert("RGB").resize((320, 320), Image.LANCZOS)
a = np.asarray(g).astype(int)
sea = (a[..., 0] < 90) & (a[..., 1] > 140) & (a[..., 2] > 190)
land = ~sea
land = ndi.binary_opening(land, iterations=1)
land = ndi.binary_dilation(land, iterations=5)      # foam halo
M = Image.fromarray((land * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(2))
cv.paste(g, (dx, dy), M)
cv.save(out)
print("saved", out, cv.size)
