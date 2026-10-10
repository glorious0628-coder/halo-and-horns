"""SurfaceAppearance maps for flat decoration plates that must shine (이미지 개발 2026-10-10, A23-107; 검수 + 이미지 생성 1:
cloth banners stay Decals, gold crests / halo ornaments / windows = a flat MeshPart + SurfaceAppearance, AlphaMode
Transparency, gold mask metal 0.9 / roughness 0.28).

  py tools/deco_sa_maps.py [names ...]        (default: the Halo shield, door halo and round window)
For art/ui/HaloDeco_<name>.png (trimmed transparent PNG): pad to a square, run 이미지 생성 1's tools/pbr_from_color.py at
1024 (flat input normal + per-material detail, --gold-boost 0.12), crop back to the image's own size, and write
art/ui/sa_halodeco/HaloDeco_<name>_{C,N,M,R}.png - C = the gold-boosted colour WITH the original alpha (the plate's
outline), N / M / R opaque. Then tools/deco_sa_preview.py renders them for the check sheet.
"""
import os
import subprocess
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI = os.path.join(ROOT, "art", "ui")
OUT = os.path.join(UI, "sa_halodeco")
WORK = os.path.join(ROOT, "build", "deco_sa")
DEFAULT = ["ShieldEmblem", "DoorHalo", "RoundWindow", "BannerPlain", "BannerEmblem", "AwningStripes"]
# 이미지 생성 1 (10/10): no gold boost - a new colour map greys the whole SurfaceAppearance while it waits for moderation,
# so the plate keeps its uploaded HaloDeco_* image as ColorMap; C here is that same image (for the previews)
GOLD_BOOST = 0.0


def fill_gold(name):
    """Painted (Firefly) gold has white highlights and dark shaded edges that the Tripo-tuned gold mask leaves out, so the
    metal map came out full of holes (the door halo's ring was metal only at its rims). For these flat plates: darker gold
    counts too (hue 18-60, saturation >= 0.3, value >= 0.35) and highlight holes enclosed by gold are closed (6 px at 1024);
    blue glass / gems stay out. The added pixels get the gold values 0.9 / 0.28."""
    import numpy as np
    from scipy import ndimage
    col = np.asarray(Image.open(os.path.join(WORK, name + "_sq.png")).convert("HSV")).astype(np.float32) / 255.0
    h, s, v = col[..., 0] * 360, col[..., 1], col[..., 2]
    mpath, rpath = os.path.join(WORK, name + "_metal.png"), os.path.join(WORK, name + "_rough.png")
    metal = np.asarray(Image.open(mpath).convert("L")).astype(np.float32) / 255.0
    rough = np.asarray(Image.open(rpath).convert("L")).astype(np.float32) / 255.0
    gold = (metal > 0.4) | ((h >= 18) & (h <= 60) & (s >= 0.3) & (v >= 0.35))
    glass = (h >= 185) & (h <= 225) & (s >= 0.15)
    closed = ndimage.binary_closing(gold, structure=np.ones((3, 3), bool), iterations=6) & ~glass
    # bigger painted highlights: a hole of the gold mask (< 2.5 % of the plate) whose rim is >= 90 % gold is gold too
    # (the shield's two top highlights); holes rimmed by glass (the window's clouds) stay as they are
    lab, n = ndimage.label(~closed)
    for i in range(1, n + 1):
        hole = lab == i
        if hole.sum() > 0.025 * hole.size:
            continue
        rim = ndimage.binary_dilation(hole, iterations=2) & ~hole
        # a gold highlight still leans gold (warm hue, a little saturation); white marble (the halo scrolls, the
        # window frame) is near-neutral and stays stone
        warm = s[hole].mean() >= 0.12 and 18 <= float(np.median(h[hole])) <= 60
        if rim.any() and closed[rim].mean() >= 0.9 and warm:
            closed |= hole & ~glass
    add = ndimage.gaussian_filter((closed & ~(metal > 0.4)).astype(np.float32), 1.0)
    metal = np.maximum(metal, add * 0.9)
    rough = rough * (1 - add) + 0.28 * add
    # window glass / gems: every blue pixel smooth (the deeper blue read as cloth, rough 0.85, in patches)
    g = ndimage.gaussian_filter(glass.astype(np.float32), 1.0)
    metal = metal * (1 - g)
    rough = rough * (1 - g) + 0.12 * g
    Image.fromarray((metal.clip(0, 1) * 255).astype(np.uint8), "L").save(mpath)
    Image.fromarray((rough.clip(0, 1) * 255).astype(np.uint8), "L").save(rpath)


def one(name):
    src = Image.open(os.path.join(UI, f"HaloDeco_{name}.png")).convert("RGBA")
    w, h = src.size
    side = max(w, h)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    ox, oy = (side - w) // 2, (side - h) // 2
    sq.paste(src, (ox, oy))
    # transparent pixels take the colour of their nearest content so the masks do not see black edges
    rgb = Image.new("RGB", (side, side), (128, 128, 128))
    rgb.paste(sq.convert("RGB"), (0, 0), sq)
    os.makedirs(WORK, exist_ok=True)
    cpath = os.path.join(WORK, name + "_sq.png")
    rgb.resize((1024, 1024), Image.LANCZOS).save(cpath)
    nin = os.path.join(WORK, name + "_flat.png")
    Image.new("RGB", (1024, 1024), (128, 128, 255)).save(nin)
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "pbr_from_color.py"), cpath, WORK, "--name", name,
                        "--size", "1024", "--normal-in", nin] + (["--gold-boost", str(GOLD_BOOST)] if GOLD_BOOST > 0 else []),
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        raise SystemExit(r.stderr[-1500:])
    fill_gold(name)
    k = 1024 / side
    box = (round(ox * k), round(oy * k), round((ox + w) * k), round((oy + h) * k))
    os.makedirs(OUT, exist_ok=True)
    files = {}
    cfn = "_color.png" if GOLD_BOOST > 0 else "_sq.png"
    for tag, fn, mode in (("C", cfn, "RGB"), ("N", "_normal.png", "RGB"), ("M", "_metal.png", "L"), ("R", "_rough.png", "L")):
        im = Image.open(os.path.join(WORK, name + fn)).convert(mode).crop(box).resize((w, h), Image.LANCZOS)
        if tag == "C":
            im = im.convert("RGBA")
            im.putalpha(src.getchannel("A"))
        p = os.path.join(OUT, f"HaloDeco_{name}_{tag}.png")
        im.save(p, optimize=True)
        files[tag] = p
    print(name, (w, h), r.stdout.strip().splitlines()[-1] if r.stdout.strip() else "")
    return files


if __name__ == "__main__":
    for n in sys.argv[1:] or DEFAULT:
        one(n)
