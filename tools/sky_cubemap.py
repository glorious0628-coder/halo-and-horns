"""
가로 파노라마 하늘 그림 → Roblox Sky 6면(2026-10-08, #12 하늘, 이미지 생성 1).

  py tools/sky_cubemap.py <pano.png> <out_dir> [--size 1024] [--horizon 0.92] [--top-deg 62] [--wrap 64]
                          [--name Sky_Day] [--repeat 3] [--check check.jpg]

- 파노라마를 둘레에 --repeat번(기본 3) 둘러 구름이 옆으로 늘지 않게 함(그림 한 장 = 120도). --wrap: 좌우 끝을 그 폭(px)만큼 섞어 이음매를 없앰.
- --horizon: 그림에서 수평선이 있는 높이(0 = 맨 위, 1 = 맨 아래). --top-deg: 그림 맨 위가 몇 도 높이인지.
  그보다 높은 하늘(위 면 가운데)은 그림 맨 위 줄 평균색으로 부드럽게 이어 칠한다(코드 그라데이션).
- 수평선 아래(아래 면, 옆면 아래쪽)는 그림 맨 아래 줄 평균색 → 조금 진한 색으로.
- 출력: <name>_Ft/Bk/Lf/Rt/Up/Dn.png (Roblox SkyboxFt 등), --check면 여러 방향으로 돌려 본 미리보기 시트.
  면 방향: Ft = 방위 0도, Rt = 90, Bk = 180, Lf = 270(위에서 보아 시계 방향). Up은 Ft 쪽이 그림 아래, Dn은 Ft 쪽이 그림 위.
  Roblox에서 방향이 틀리면 면 이름만 바꾸거나 돌리면 된다(검사 시트로 확인).
"""
import argparse
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

FACES = {"Ft": 0.0, "Rt": 90.0, "Bk": 180.0, "Lf": 270.0}


def load_pano(path, wrap):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    if wrap > 0:
        H, W, _ = a.shape
        t = np.linspace(0, 1, wrap)[None, :, None]
        # crossfade the last `wrap` columns into the first ones and drop them: the new last column is
        # the original column next to the new first column, so the picture runs on round the circle
        head = a[:, W - wrap:] * (1 - t) + a[:, :wrap] * t
        a = np.concatenate([head, a[:, wrap:W - wrap]], 1)
    return a


class Sky:
    def __init__(self, pano, horizon, top_deg, zenith_soften=0.0, down_color=None):
        self.p = pano
        self.H, self.W, _ = pano.shape
        self.hy = horizon * self.H
        self.ppd = self.hy / top_deg  # pixels per degree above the horizon
        self.top_deg = top_deg
        self.top_col = pano[:6].reshape(-1, 3).mean(0)
        self.low_col = pano[-6:].reshape(-1, 3).mean(0)
        self.dn_col = np.array(down_color, np.float32) if down_color is not None else self.low_col * 0.92
        # pure vertical gradient (row median) for the high sky: near the zenith all directions meet, so any
        # left-right colour change in the picture would draw a fan of wedges there (no ray-burst rule)
        self.grad = np.median(pano, axis=1)
        self.fade0 = 36.0
        if zenith_soften > 0:  # make the darker round zenith spot weaker: pull the top colour toward the ring colour
            ring = self.grad[int(np.clip(self.hy - (top_deg - 14) * self.ppd, 0, self.H - 1))]
            self.top_col = self.top_col * (1 - zenith_soften) + ring * zenith_soften
            n = max(1, int(self.hy - (top_deg - 14) * self.ppd))
            w = np.linspace(zenith_soften, 0, n)[:, None]
            self.grad[:n] = self.grad[:n] * (1 - w) + ring * w

    def sample(self, az, el):
        """az, el in degrees (arrays). bilinear sample with code gradients outside the picture."""
        x = (az % 360.0) / 360.0 * self.W
        y = self.hy - el * self.ppd
        yc = np.clip(y, 0, self.H - 1.001)
        x0 = np.floor(x).astype(int) % self.W
        x1 = (x0 + 1) % self.W
        y0 = np.floor(yc).astype(int)
        y1 = np.minimum(y0 + 1, self.H - 1)
        fx = (x - np.floor(x))[..., None]
        fy = (yc - y0)[..., None]
        p = self.p
        c = (p[y0, x0] * (1 - fx) + p[y0, x1] * fx) * (1 - fy) + (p[y1, x0] * (1 - fx) + p[y1, x1] * fx) * fy
        # high sky: from fade0 up to the picture top, blend into the plain vertical gradient
        g = self.grad[y0] * (1 - fy) + self.grad[y1] * fy
        z = np.clip((el - self.fade0) / max(1.0, self.top_deg - self.fade0), 0, 1)[..., None]
        z = z * z * (3 - 2 * z)
        c = c * (1 - z) + g * z
        # above the picture: fade to the top colour over 10 degrees
        over = np.clip((el - self.top_deg) / 10.0, 0, 1)[..., None]
        c = c * (1 - over) + self.top_col * over
        # below the picture bottom: fade to the down colour
        bottom_el = (self.hy - (self.H - 1)) / self.ppd
        under = np.clip((bottom_el - el) / 12.0, 0, 1)[..., None]
        c = c * (1 - under) + self.dn_col * under
        return c


def face_dirs(n, face):
    s = (np.arange(n) + 0.5) / n * 2 - 1
    u, v = np.meshgrid(s, -s)  # u right, v up
    if face in FACES:
        a = math.radians(FACES[face])
        fx, fz = math.sin(a), math.cos(a)  # forward on the ground plane
        rx, rz = math.cos(a), -math.sin(a)  # right
        dx = fx + u * rx
        dz = fz + u * rz
        dy = v
    elif face == "Up":  # looking up, Ft (az 0) at the bottom of the image
        dx, dz, dy = u, -v, np.ones_like(u)
    else:  # Dn, Ft at the top of the image
        dx, dz, dy = u, v, -np.ones_like(u)
    return dx, dy, dz


def to_azel(dx, dy, dz):
    az = np.degrees(np.arctan2(dx, dz)) % 360.0
    el = np.degrees(np.arctan2(dy, np.hypot(dx, dz)))
    return az, el


def render_view(sky, yaw, pitch, fov=75, w=480, h=300):
    f = 1 / math.tan(math.radians(fov) / 2)
    xs = (np.arange(w) + 0.5) / w * 2 - 1
    ys = ((np.arange(h) + 0.5) / h * 2 - 1) * h / w
    X, Y = np.meshgrid(xs, -ys)
    d = np.stack([X, Y, np.full_like(X, f)], -1)
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    y2 = d[..., 1] * cp + d[..., 2] * sp
    z2 = -d[..., 1] * sp + d[..., 2] * cp
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    x3 = d[..., 0] * cy + z2 * sy
    z3 = -d[..., 0] * sy + z2 * cy
    az, el = to_azel(x3, y2, z3)
    return sky.sample(az, el)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pano")
    ap.add_argument("out_dir")
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--horizon", type=float, default=0.92)
    ap.add_argument("--top-deg", type=float, default=62.0)
    ap.add_argument("--wrap", type=int, default=64)
    ap.add_argument("--name", default="Sky_Day")
    ap.add_argument("--repeat", type=int, default=3, help="how many times the picture goes round the 360 degrees (keeps clouds round)")
    ap.add_argument("--check")
    ap.add_argument("--zenith-soften", type=float, default=0.0, help="0..1: weaken the darker blue round spot straight up")
    ap.add_argument("--down-color", help="R,G,B for below the horizon (match Lighting/Atmosphere fog colour)")
    a = ap.parse_args()
    pano = load_pano(a.pano, a.wrap)
    if a.repeat > 1:
        pano = np.concatenate([pano] * a.repeat, 1)
    dc = [float(v) for v in a.down_color.split(",")] if a.down_color else None
    sky = Sky(pano, a.horizon, a.top_deg, a.zenith_soften, dc)
    os.makedirs(a.out_dir, exist_ok=True)
    faces = {}
    for face in ["Ft", "Rt", "Bk", "Lf", "Up", "Dn"]:
        az, el = to_azel(*face_dirs(a.size, face))
        img = np.clip(sky.sample(az, el), 0, 255).astype(np.uint8)
        faces[face] = Image.fromarray(img)
        faces[face].save(os.path.join(a.out_dir, "%s_%s.png" % (a.name, face)))
    if a.check:
        f = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 16)
        views = [(yaw, pitch) for pitch in (8, 35, 70) for yaw in (0, 45, 90, 180, 270)]
        views[-1] = (0, 89)
        w, h = 360, 225
        sh = Image.new("RGB", (w * 5 + 60, h * 3 + 40 + 330), (236, 236, 236))
        d = ImageDraw.Draw(sh)
        d.text((10, 8), "views turned around (yaw / pitch deg) - check seams between faces and at the wrap", fill=(0, 0, 0), font=f)
        for i, (yaw, pitch) in enumerate(views):
            im = Image.fromarray(np.clip(render_view(sky, yaw, pitch, w=w, h=h), 0, 255).astype(np.uint8))
            x, y = 10 + (i % 5) * (w + 8), 34 + (i // 5) * (h + 6)
            sh.paste(im, (x, y))
            d.text((x + 4, y + 4), "yaw %d / pitch %d" % (yaw, pitch), fill=(0, 0, 0), font=f, stroke_width=2, stroke_fill=(255, 255, 255))
        # cube cross
        c = 100
        y0 = 34 + 3 * (h + 6) + 6
        pos = {"Up": (1, 0), "Lf": (0, 1), "Ft": (1, 1), "Rt": (2, 1), "Bk": (3, 1), "Dn": (1, 2)}
        for k, (cx, cy) in pos.items():
            sh.paste(faces[k].resize((c, c)), (10 + cx * c, y0 + cy * c))
            d.text((14 + cx * c, y0 + cy * c + 2), k, fill=(0, 0, 0), font=f)
        sh.save(a.check, quality=88)
    print("[sky_cubemap]", a.out_dir, a.name, a.size)


main()
