"""Replace the two round pond slimes in WorldMap_v2_A2_2 with our cube jelly slime (CON_SlimeCube).

User asked (via review, A23-53): the big-map art must show our square jelly slime, not round blobs.
Steps: find the two green blobs in the pond -> inpaint them with water (OpenCV Telea + light grain)
-> paste the approved CON_SlimeCube cutout at the same spots, bottom cut along a curved waterline,
soft shadow + light ring on the water. 0 Firefly credits.

Usage (as used 2026-10-06):
  py tools/cutout_flat.py art/out/CON_SlimeCube.png <tmp>/slimecube_cut.png --size 512 --fill 0.9
  py tools/worldmap_slimefix.py <tmp>/slimecube_cut.png art/out/worldmap/WorldMap_v2_A2_2_slimefix.png 0.14 1.08 1.25
  args: <cut> <out> [submerged share 0.14] [size scale 1.08] [saturation 1.25]
"""
import sys
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

SRC = 'art/out/worldmap/WorldMap_v2_A2_2.png'
CUT = sys.argv[1]            # slimecube_cut.png (512 RGBA)
OUT = sys.argv[2]
SUB = float(sys.argv[3]) if len(sys.argv) > 3 else 0.16   # submerged share of the body height
SCALE = float(sys.argv[4]) if len(sys.argv) > 4 else 1.0
SAT = float(sys.argv[5]) if len(sys.argv) > 5 else 1.2

base = Image.open(SRC).convert('RGB')
arr = np.asarray(base).astype(np.int32)

# 1) find the two green blobs (from the detection pass)
x0, y0, x1, y1 = 370, 570, 500, 680
reg = arr[y0:y1, x0:x1]
R, G, B = reg[..., 0], reg[..., 1], reg[..., 2]
green = (G > R + 25) & (G > B + 25) & (G > 120)
lab, n = ndimage.label(green)
blobs = []
for i in range(1, n + 1):
    ys, xs = np.where(lab == i)
    bx0, bx1, by0, by1 = xs.min() + x0, xs.max() + x0, ys.min() + y0, ys.max() + y0
    if (abs(bx0 - 396) < 4 and abs(by0 - 595) < 4) or (abs(bx0 - 429) < 4 and abs(by0 - 623) < 4):
        m = np.zeros(arr.shape[:2], bool)
        m[ys + y0, xs + x0] = True
        blobs.append((m, (bx0, bx1, by0, by1)))
assert len(blobs) == 2, blobs

# 2) inpaint mask = blob dilated + ring/shadow band around its lower half
mask = np.zeros(arr.shape[:2], np.uint8)
for m, (bx0, bx1, by0, by1) in blobs:
    d = ndimage.binary_dilation(m, iterations=3)
    mask[d] = 255
    cx, w = (bx0 + bx1) / 2, bx1 - bx0
    # lower ring + left shadow
    cv2.ellipse(mask, (int(cx - 2), int(by1 - 2)), (int(w / 2 + 6), 7), 0, 0, 360, 255, -1)
mask = cv2.dilate(mask, np.ones((3, 3), np.uint8), iterations=1)
bgr = cv2.cvtColor(np.asarray(base), cv2.COLOR_RGB2BGR)
clean = cv2.inpaint(bgr, mask, 6, cv2.INPAINT_TELEA)
clean = cv2.cvtColor(clean, cv2.COLOR_BGR2RGB)
# soften the inpainted area a bit and add faint grain so it is not glassy
blur = cv2.GaussianBlur(clean, (0, 0), 1.2)
mf = cv2.GaussianBlur(mask.astype(np.float32) / 255.0, (0, 0), 1.5)[..., None]
rng = np.random.default_rng(7)
grain = rng.normal(0, 2.0, clean.shape)
clean = (clean * (1 - mf) + (blur + grain) * mf).clip(0, 255).astype(np.uint8)
out = Image.fromarray(clean).convert('RGBA')

# 3) slime sprite: trim, find body width (row widths below the crystals)
spr = Image.open(CUT).convert('RGBA')
a = np.asarray(spr)[..., 3]
ys, xs = np.where(a > 128)
spr = spr.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
a = np.asarray(spr)[..., 3] > 128
rows = a.sum(1)
body_w = np.percentile(rows, 90)          # widest rows = body
# body top = first row whose width > 70% of body width
body_top = int(np.argmax(rows > 0.7 * body_w))
H0, W0 = a.shape

def place(img, cx, waterline, target_w):
    k = target_w / body_w
    sw, sh = max(1, round(W0 * k)), max(1, round(H0 * k))
    s = spr.resize((sw * 4, sh * 4), Image.LANCZOS).resize((sw, sh), Image.LANCZOS)
    # a little more colour so the cube sits in the vivid map palette
    from PIL import ImageEnhance
    rgb, alpha = s.convert('RGB'), s.getchannel('A')
    rgb = ImageEnhance.Color(rgb).enhance(SAT)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.06)
    s = rgb.convert('RGBA'); s.putalpha(alpha)
    body_h = (H0 - body_top) * k
    sub = body_h * SUB
    sa = np.asarray(s).astype(np.float32)
    rw = body_w * k * 0.56          # ring half-width
    rh = max(2.0, body_w * k * 0.13) # ring half-height (top view of a flat circle)
    left = cx - sw / 2
    xs = np.arange(sw) + left - cx + 0.5
    arc = rh * np.sqrt(np.clip(1 - (xs / rw) ** 2, 0, 1))      # front arc offset per column
    cut_row = (sh - sub) + arc - rh * 0.4                       # visible bottom follows the front arc
    rowsi = np.arange(sh)[:, None]
    ramp = np.clip((cut_row[None, :] - rowsi) / 1.6, 0, 1)
    sa[..., 3] *= ramp
    s = Image.fromarray(sa.clip(0, 255).astype(np.uint8))
    top = waterline - (sh - sub)
    li, ti = int(round(left)), int(round(top))
    W, H = img.size
    # soft shadow on the water, left of the slime (light comes from the upper right)
    sh_layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dsh = ImageDraw.Draw(sh_layer)
    dsh.ellipse((cx - rw * 1.25, waterline - rh * 0.9, cx + rw * 0.35, waterline + rh * 1.3), fill=(8, 55, 125, 70))
    img.alpha_composite(sh_layer.filter(ImageFilter.GaussianBlur(2.0)))
    # lighter water glow around the waterline (soft, no hard stroke)
    glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dg = ImageDraw.Draw(glow)
    dg.ellipse((cx - rw * 1.08, waterline - rh * 1.05, cx + rw * 1.08, waterline + rh * 1.05), outline=(170, 230, 255, 120), width=2)
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(1.1)))
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    layer.alpha_composite(s, (li, ti))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.3)))
    # thin front highlight where the jelly meets the water
    hl = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dh = ImageDraw.Draw(hl)
    dh.arc((cx - rw * 0.98, waterline - rh * 1.0 - rh * 0.4, cx + rw * 0.98, waterline + rh * 1.0 - rh * 0.4), 15, 165, fill=(215, 248, 255, 150), width=1)
    img.alpha_composite(hl.filter(ImageFilter.GaussianBlur(0.5)))
    return (li, ti, sw, sh)

info = []
for m, (bx0, bx1, by0, by1) in blobs:
    w = (bx1 - bx0 + 1) * SCALE
    cx = (bx0 + bx1) / 2
    waterline = by1 - 2
    info.append(place(out, cx, waterline, w))
out.convert('RGB').save(OUT)
print('placed', info, 'body_w', body_w, 'body_top', body_top)
