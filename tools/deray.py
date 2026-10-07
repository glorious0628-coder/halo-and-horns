"""
빛살(욱일기처럼 퍼지는 빛줄기) 지우기 — 0 크레딧. 사용자 규칙 2026-10-07: 빛은 둥근 빛무리 + 반짝이만.

  py tools/deray.py <in.png> <out.png> <spec.json>

빛줄기가 한 점(origin)에서 퍼지면, 그 점을 중심으로 극좌표로 펴서 각도 방향으로만 흐리면 줄무늬가 사라지고
가운데가 밝은 둥근 그라데이션(빛무리)만 남는다. 주인공·후광·수정·반짝이·구름은 건드리지 않는다.

spec.json:
{
 "origin": [x, y] | "auto",              # 빛줄기가 모이는 점(auto = 줄무늬 방향으로 추정)
 "bg": [{"h": [30, 62], "s": [0.45, 1], "v": [0.55, 1]}],   # 지울 배경 색 범위(HSV, h 도)
 "flood_dark": 0.25,                     # 진한 외곽선 안쪽(테두리에서 안 닿는 곳) = 주인공으로 보호, 끄려면 null
 "flood_close": 0,                        # 외곽선 틈 메우기(px) — 틈으로 새면 주인공 안까지 바뀜
 "fill_outline": {"v": 0.25, "close": 4, "min_area": 0.001},  # 진한 바깥 테두리 모양을 통째로 채워 보호(갈라진 틈이 있어도)
 "protect": [{"ellipse": [cx, cy, ax, by], "ring": 0, "pad": 18}, {"poly": [[x,y],...], "pad": 12}, {"circle": [cx, cy, r]}],
 "sigma_deg": 9,                         # 각도 방향 흐림(도)
 "keep_sparkles": true,                  # 작은 흰 별은 원래 그림을 다시 얹음
 "sparkle_mode": "disc",                 # disc = 별 둘레 원까지 원래대로(아이콘) / add = 별의 밝은 부분만 새 배경 위에(썸네일, 작은 원이 안 보임)
 "feather": 10,
 "region": [x0, y0, x1, y1] | null,      # 이 사각형 안만 손댐(썸네일처럼 일부만 고칠 때)
 "min_component": 0.01,                  # 배경과 이어진 큰 덩어리만 바꿈(버클 같은 작은 금 조각은 그대로)
 "radial_blur": 9,                       # 반지름 방향 흐림(px) — 크면 빛무리 고리 무늬가 더 매끈
 "soft_h": 0, "soft_sv": 0,              # 색 경계를 부드럽게(색상 도, 채도·밝기) — 경계 이음매가 보일 때 8, 0.1 정도
 "protect_color": [{"h": [15, 52], "s": [0.55, 1], "v": [0.3, 1], "pad": 6}],  # 이 색은 보호(예: 금 왕관 조각)
 "radial_limit": [r_full, r_zero],       # 중심에서 r_full까지 다 바꾸고 r_zero에서 0(썸네일처럼 가운데만)
 "protect_soft": 0                       # 보호 영역·범위 가장자리 쪽으로 서서히(px) — 하늘에 직선 경계가 보일 때
}
결과: out.png, out_mask.png(어디를 바꿨는지)
"""
import json
import math
import sys

import cv2
import numpy as np
from PIL import Image

IN, OUT, SPEC = sys.argv[1:4]
sp = json.load(open(SPEC, encoding="utf-8"))
im = np.asarray(Image.open(IN).convert("RGB"))
H, W = im.shape[:2]
hsv = cv2.cvtColor(im, cv2.COLOR_RGB2HSV_FULL).astype(np.float32)
h, s, v = hsv[..., 0] / 255 * 360, hsv[..., 1] / 255, hsv[..., 2] / 255

# 1. background colour mask (hard core + soft weight, so the replaced area fades out where the colour drifts away)
SOFT_H, SOFT_SV = float(sp.get("soft_h", 0)), float(sp.get("soft_sv", 0))


def ramp(x, lo, hi, soft):
    if soft <= 0:
        return ((x >= lo) & (x <= hi)).astype(np.float32)
    return np.clip((x - lo) / soft + 1, 0, 1) * np.clip((hi - x) / soft + 1, 0, 1)


bg = np.zeros((H, W), bool)
bgw = np.zeros((H, W), np.float32)
for b in sp.get("bg", [{"h": [30, 62], "s": [0.45, 1], "v": [0.55, 1]}]):
    h0, h1 = b["h"]
    hm = (h >= h0) & (h <= h1) if h0 <= h1 else (h >= h0) | (h <= h1)
    bg |= hm & (s >= b["s"][0]) & (s <= b["s"][1]) & (v >= b["v"][0]) & (v <= b["v"][1])
    hh = h if h0 <= h1 else np.where(h < h1 + 180, h + 360, h)
    hw = ramp(hh, h0, h1 if h0 <= h1 else h1 + 360, SOFT_H)
    bgw = np.maximum(bgw, hw * ramp(s, b["s"][0], b["s"][1], SOFT_SV) * ramp(v, b["v"][0], b["v"][1], SOFT_SV))

# 2. protected subject
protect = np.zeros((H, W), np.uint8)
if sp.get("flood_dark") is not None:
    dark = (v <= float(sp["flood_dark"])).astype(np.uint8)
    fc = int(sp.get("flood_close", 0))
    if fc:  # close small gaps in the dark outline so the flood cannot leak inside the subject
        dark = cv2.dilate(dark, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * fc + 1, 2 * fc + 1)))
    passable = (1 - dark).astype(np.uint8)
    reach = np.zeros((H + 2, W + 2), np.uint8)
    pas = passable.copy()
    for (x, y) in [(0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)] + [(x, 0) for x in range(0, W, 16)] + [(x, H - 1) for x in range(0, W, 16)] + [(0, y) for y in range(0, H, 16)] + [(W - 1, y) for y in range(0, H, 16)]:
        if pas[y, x] and not reach[y + 1, x + 1]:
            cv2.floodFill(pas, reach, (x, y), 2, flags=4 | (255 << 8) | cv2.FLOODFILL_MASK_ONLY)
    reached = reach[1:-1, 1:-1] > 0
    protect |= (~reached).astype(np.uint8)
if sp.get("fill_outline"):
    # fill every closed dark outline as a whole silhouette (works even when cracks open the inside)
    fo = sp["fill_outline"]
    dark = (v <= float(fo.get("v", 0.25))).astype(np.uint8)
    dark = cv2.dilate(dark, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * int(fo.get("close", 4)) + 1,) * 2))
    cnts, _ = cv2.findContours(dark, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    sil = np.zeros((H, W), np.uint8)
    for c in cnts:
        if cv2.contourArea(c) >= float(fo.get("min_area", 0.001)) * H * W:
            cv2.drawContours(sil, [c], -1, 1, -1)
    protect |= sil
for p in sp.get("protect", []):
    m = np.zeros((H, W), np.uint8)
    if "ellipse" in p:
        cx, cy, ax, by = p["ellipse"]
        cv2.ellipse(m, (int(cx), int(cy)), (int(ax), int(by)), 0, 0, 360, 1, -1)
        if p.get("ring"):
            cv2.ellipse(m, (int(cx), int(cy)), (max(1, int(ax - p["ring"])), max(1, int(by - p["ring"]))), 0, 0, 360, 0, -1)
    elif "poly" in p:
        cv2.fillPoly(m, [np.array(p["poly"], np.int32)], 1)
    elif "circle" in p:
        cx, cy, r = p["circle"]
        cv2.circle(m, (int(cx), int(cy)), int(r), 1, -1)
    pad = int(p.get("pad", 0))
    if pad:
        m = cv2.dilate(m, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * pad + 1, 2 * pad + 1)))
    protect |= m
for pc in sp.get("protect_color", []):
    h0, h1 = pc["h"]
    hm = (h >= h0) & (h <= h1) if h0 <= h1 else (h >= h0) | (h <= h1)
    cm = (hm & (s >= pc["s"][0]) & (s <= pc["s"][1]) & (v >= pc["v"][0]) & (v <= pc["v"][1])).astype(np.uint8)
    cm = cv2.morphologyEx(cm, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    pad = int(pc.get("pad", 4))
    if pad:
        cm = cv2.dilate(cm, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * pad + 1, 2 * pad + 1)))
    protect |= cm
protect = cv2.dilate(protect, np.ones((5, 5), np.uint8))

# sparkles: small, very bright, low saturation blobs
spark = np.zeros((H, W), np.uint8)
spark_core = np.zeros((H, W), np.uint8)
if sp.get("keep_sparkles", True):
    hot = ((v > 0.93) & (s < 0.4)).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(hot, 8)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] < float(sp.get("sparkle_max_area", 0.0006)) * H * W:
            spark[lab == i] = 1
    spark_core = spark.copy()
    sd = int(sp.get("sparkle_pad", 0.03 * W)) | 1
    spark = cv2.dilate(spark, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (sd, sd)))

region = np.ones((H, W), bool)
if sp.get("region"):
    x0, y0, x1, y1 = sp["region"]
    region[:] = False
    region[y0:y1, x0:x1] = True
use = bg & (protect == 0) & (spark == 0) & region  # pixels that feed the smoothing and get replaced
# only big background areas: small gold islands (buckles, trims, shards inside outlines) stay untouched
mc = float(sp.get("min_component", 0.01))
if mc > 0:
    n, lab, st, _ = cv2.connectedComponentsWithStats(use.astype(np.uint8), 8)
    keep = np.zeros(n, bool)
    keep[1:] = st[1:, cv2.CC_STAT_AREA] >= mc * H * W
    use = keep[lab]
if SOFT_H > 0 or SOFT_SV > 0:
    # soft fringe: pixels near the kept background whose colour is only partly 'background' are partly replaced
    near = cv2.dilate(use.astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (41, 41))) > 0
    usew = np.where(use, 1.0, bgw * near) * (protect == 0) * (spark == 0) * region
else:
    usew = use.astype(np.float32)

# 3. origin
if sp.get("origin", "auto") == "auto":
    g = cv2.GaussianBlur(cv2.cvtColor(im, cv2.COLOR_RGB2GRAY).astype(np.float32), (0, 0), 4)
    gx, gy = cv2.Sobel(g, cv2.CV_32F, 1, 0, ksize=5), cv2.Sobel(g, cv2.CV_32F, 0, 1, ksize=5)
    Jxx, Jyy, Jxy = (cv2.GaussianBlur(x, (0, 0), 12) for x in (gx * gx, gy * gy, gx * gy))
    th = 0.5 * np.arctan2(2 * Jxy, Jxx - Jyy)
    coh = np.sqrt((Jxx - Jyy) ** 2 + 4 * Jxy ** 2) / (Jxx + Jyy + 1e-6)
    ys, xs = np.nonzero(use[::8, ::8])
    ys, xs = ys * 8, xs * 8
    w = coh[ys, xs] * (coh[ys, xs] > 0.3)
    nx, ny = np.cos(th[ys, xs]), np.sin(th[ys, xs])  # gradient direction = normal of the ray line
    A = np.array([[np.sum(w * nx * nx), np.sum(w * nx * ny)], [np.sum(w * nx * ny), np.sum(w * ny * ny)]])
    bb = np.array([np.sum(w * nx * (nx * xs + ny * ys)), np.sum(w * ny * (nx * xs + ny * ys))])
    ox, oy = np.linalg.solve(A, bb)
else:
    ox, oy = sp["origin"]
print("origin", round(float(ox)), round(float(oy)))

if sp.get("radial_limit"):
    r_full, r_zero = sp["radial_limit"]
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    rr = np.hypot(xx - ox, yy - oy)
    usew = usew * np.clip((r_zero - rr) / max(r_zero - r_full, 1), 0, 1)
# 4. angular smoothing in polar space (normalized convolution: only background pixels feed it)
R = int(math.hypot(max(ox, W - ox), max(oy, H - oy))) + 2
NA = 2880
img_f = im.astype(np.float32)
wgt = usew.astype(np.float32)
flags = cv2.WARP_POLAR_LINEAR + cv2.INTER_LINEAR
P = cv2.warpPolar(img_f * wgt[..., None], (R, NA), (ox, oy), R, flags)
PW = cv2.warpPolar(wgt, (R, NA), (ox, oy), R, flags)
sig = float(sp.get("sigma_deg", 9)) / 360 * NA


def ablur(x):
    # wrap-around blur along the angle axis (rows)
    pad = int(3 * sig)
    xp = np.concatenate([x[-pad:], x, x[:pad]], 0)
    k = cv2.getGaussianKernel(2 * pad + 1, sig).astype(np.float32)
    return cv2.filter2D(xp, -1, k, borderType=cv2.BORDER_REPLICATE)[pad:-pad] if x.ndim == 2 else \
        np.stack([cv2.filter2D(xp[..., c], -1, k, borderType=cv2.BORDER_REPLICATE)[pad:-pad] for c in range(x.shape[2])], -1)


Pb, PWb = ablur(P), ablur(PW)
# a little blur along the radius too, so the glow stays smooth
rb = int(sp.get("radial_blur", 9)) | 1
Pb = cv2.blur(Pb, (rb, 1))
PWb = cv2.blur(PWb, (rb, 1))
S = Pb / np.maximum(PWb[..., None], 1e-4)
back = cv2.warpPolar(S, (W, H), (ox, oy), R, flags + cv2.WARP_INVERSE_MAP)
backW = cv2.warpPolar(PWb, (W, H), (ox, oy), R, flags + cv2.WARP_INVERSE_MAP)

# 5. blend: replace only background pixels (feathered); keep everything else
f = int(sp.get("feather", 10))
ub = usew.copy()
if spark.any() and sp.get("sparkle_mode", "disc") == "add":  # fill the sparkle discs from their surroundings so no disc of old background is left
    ub = np.where(spark > 0, cv2.dilate(usew, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (int(sp.get('sparkle_pad', 0.03 * W)) * 2 + 1,) * 2)), usew)
    ub = ub * (protect == 0) * region
m = ub * (backW > 0.05)
m = cv2.GaussianBlur(m, (0, 0), f / 2) * (ub > 0)  # never bleed onto protected pixels
m = np.clip(m * 1.4, 0, 1) * np.clip(ub * 1.5, 0, 1)
ps = float(sp.get("protect_soft", 0))
if ps > 0:  # fade out towards protected areas and the region edge, so their straight edges never show in open sky
    hard = ((protect > 0) | ~region).astype(np.float32)
    keep_soft = np.maximum(hard, cv2.GaussianBlur(hard, (0, 0), ps))
    m = m * (1 - keep_soft)
out = img_f * (1 - m[..., None]) + back * m[..., None]
if spark_core.any() and sp.get("sparkle_mode", "disc") == "add":  # put the sparkles back: only their extra brightness over the local background
    loc = cv2.medianBlur(im, 21).astype(np.float32)
    excess = np.clip(img_f - loc, 0, 255)
    core = cv2.GaussianBlur(cv2.dilate(spark_core, np.ones((5, 5), np.uint8)).astype(np.float32), (0, 0), 2)
    out = out + excess * (core * m)[..., None]
# keep the original sparkles exactly
out = np.clip(out, 0, 255).astype(np.uint8)
Image.fromarray(out).save(OUT)
Image.fromarray((m * 255).astype(np.uint8)).save(OUT.replace(".png", "_mask.png"))
print("[deray] replaced %.1f%% of pixels -> %s" % (100 * (m > 0.5).mean(), OUT))
