"""Roblox material tuning of HD Tripo maps: gold + marble models (이미지 생성 3, 10/14, docs/design/roblox_material_hd_2026-10-14.md).

  py tools/hd_mat_tune.py <raw_dir> <out_dir> [--prefix Name_m] [--gold-m 0.90] [--gold-r 0.30] [--marble-r 0.50] [--gain 1.35]

Reads <prefix><k>_{C,N,R,M}.png (tools/glb_sa_maps_multi.py), writes tuned maps with the same names to out_dir (N unchanged).
gold mask = saturated yellow-orange colour OR metalness > 0.5 (soft edge): metal 0.90, rough 0.30, hue pulled to ~42 deg, saturation up,
value >= 0.80. everything else = marble: metal 0, rough 0.50 (+/- the old map's detail), contrast up around the median, white
point 0.96. Also writes <out_dir>/_tuned_check.jpg (raw | tuned colour | gold mask | tuned R | tuned M per material).
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

a = sys.argv[1:]
raw, out = a[0], a[1]
opt = lambda k, d: type(d)(a[a.index(k) + 1]) if k in a else d  # noqa: E731
prefix = opt("--prefix", "")
GM, GR, MR, GAIN = opt("--gold-m", 0.90), opt("--gold-r", 0.30), opt("--marble-r", 0.50), opt("--gain", 1.35)
os.makedirs(out, exist_ok=True)
ks = sorted({int(f[len(prefix):].split("_")[0]) for f in os.listdir(raw) if f.startswith(prefix) and f.endswith("_C.png")})
rows = []
for k in ks:
    p = os.path.join(raw, "%s%d_" % (prefix, k))
    C0 = Image.open(p + "C.png").convert("RGB")
    R0 = np.asarray(Image.open(p + "R.png").convert("L"), np.float32) / 255
    M0 = np.asarray(Image.open(p + "M.png").convert("L"), np.float32) / 255
    hsv = np.asarray(C0.convert("HSV"), np.float32) / 255
    H, S, V = hsv[..., 0] * 360, hsv[..., 1], hsv[..., 2]
    ss = lambda x, lo, hi: np.clip((x - lo) / (hi - lo), 0, 1) ** 2 * (3 - 2 * np.clip((x - lo) / (hi - lo), 0, 1))  # noqa: E731
    mask = np.maximum(ss(S, 0.30, 0.50) * (H > 22) * (H < 62), ss(M0, 0.35, 0.65))
    mask = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255
    rgb = np.asarray(C0, np.float32) / 255
    # gold colour: hue 42, saturation up, value >= 0.80
    gh = np.clip(H, 36, 48) * 0 + 42
    gs = np.clip(S * 1.15 + 0.10, 0.62, 0.97)
    gv = np.clip(V * 1.05, 0.80, 1.0)
    gimg = Image.fromarray(np.stack([gh / 360, gs, gv], -1).__mul__(255).astype(np.uint8), "HSV").convert("RGB")
    gold = np.asarray(gimg, np.float32) / 255
    # marble colour: ivory (2D marble ~255,244,222): median value -> 0.92, contrast up on V, soft clip, hue fixed ~36 deg, low saturation
    sel = (mask < 0.2)
    med = float(np.median(V[sel])) if sel.any() else 0.85
    tgt = 0.92
    v = V * (tgt / max(med, 1e-3))
    v = (v - tgt) * GAIN + tgt
    v = np.where(v > 0.94, 0.94 + 0.05 * np.tanh((v - 0.94) / 0.05), v)
    v = np.clip(v, 0.05, 0.99)
    mx = float(np.percentile(v[sel], 99.5)) if sel.any() else 1.0
    ms = np.clip(S * 0.8 + 0.03, 0.05, 0.16)
    mimg = Image.fromarray(np.stack([np.full_like(v, 36 / 360), ms, v], -1).__mul__(255).astype(np.uint8), "HSV").convert("RGB")
    m = np.asarray(mimg, np.float32) / 255
    mk = mask[..., None]
    C = np.clip(gold * mk + m * (1 - mk), 0, 1)
    R = np.clip(GR * mask + (MR + (R0 - float(np.median(R0[sel] if sel.any() else R0))) * 0.8) * (1 - mask), 0.08, 0.95)
    R = np.where(mask > 0.5, GR + 0 * R, R)
    M = np.clip(GM * mask, 0, 1)
    im = lambda x: Image.fromarray((np.clip(x, 0, 1) * 255 + 0.5).astype(np.uint8))  # noqa: E731
    im(C).save(p.replace(raw, out) + "C.png") if False else None
    q = os.path.join(out, "%s%d_" % (prefix, k))
    im(C).save(q + "C.png")
    Image.open(p + "N.png").save(q + "N.png")
    im(R).save(q + "R.png")
    im(M).save(q + "M.png")
    print("[m%d] marble median %.2f p99.5 %.2f gold share %.1f%%" % (k, med, mx, 100 * float((mask > 0.5).mean())))
    rows.append([C0, im(C).convert("RGB"), im(mask).convert("RGB"), im(R).convert("RGB"), im(M).convert("RGB")])
T = 260
sheet = Image.new("RGB", (5 * (T + 4), len(rows) * (T + 4)), (40, 40, 40))
for r, row in enumerate(rows):
    for c, i2 in enumerate(row):
        t = i2.copy(); t.thumbnail((T, T)); sheet.paste(t, (c * (T + 4), r * (T + 4)))
sheet.save(os.path.join(out, "_tuned_check.jpg"), quality=88)
