"""
Faction cosmetic recolors (A23-75 / A23-77, 0 credits): the rank halo / horns meshes (art/models/acc/Acc_{Halo,Horns}R1-R5.glb)
keep their shape; only the base-colour texture is repainted per theme, like the crossroads stall awning swap.

  py tools/img2/acc_recolor.py [theme ...]        all themes when none given
  -> build/acctex/<theme>/Acc_<Kind>R<r>.png (R3-R5: 1024, the upload size; R1/R2 share the 64 px palette AccPalette)
     + build/acctex/themes.json (theme -> kind, glow / sparkle colours for the round glow and small stars)

Pixel classes (soft weights, HSV): gold (h 30-65), orange (h 17-30), red (h -25..17), white (low saturation, bright).
A theme maps each class to a new hue / saturation and a value curve; for horn reds the colour is blended between a
dark and a light theme colour by the pixel's brightness inside the red class (light stripes -> light colour), so
striped R2 / R3 horns keep their bands. Everything else (outlines, black) is left alone.
"""
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")).replace("\\", "/") + "/"
SRC = ROOT + "build/acctex/"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# class -> ("set", H, S, Vmul)  or  ("blend", (H,S,V) dark, (H,S,V) light) for reds  or None = keep
THEMES = {
    # shop (A23-75, user pick 292051f)
    "HaloIce": {"kind": "Halo", "gold": ("set", 198, 0.42, 1.08), "orange": ("set", 192, 0.45, 1.05), "white": ("set", 203, 0.26, 1.0),
                "red": ("set", 205, 0.5, 1.0), "glow": (170, 225, 255), "sparkle": (225, 245, 255)},
    # HaloGold emblem: was ruby (352) = a red spiky sun on R4 / R5 (검수 10/08) -> bright pale gold, and on R4 / R5 only the
    # round centre (emblemcore mask), not the side pieces along the ring
    "HaloGold": {"kind": "Halo", "gold": ("set", 33, 0.86, 0.93), "orange": ("set", 30, 0.88, 0.93), "white": ("set", 44, 0.55, 1.0),
                 "red": ("set", 44, 0.6, 1.1), "emblem": ("set", 46, 0.6, 1.15), "emblem_mask": "emblemcore",
                 "glow": (255, 170, 110), "sparkle": (255, 210, 120)},
    "HornsLava": {"kind": "Horns", "tcurve": (0.5, 0.95), "red": ("blend", (6, 0.5, 0.17), (26, 0.98, 1.0)), "gold": ("set", 30, 1.0, 1.08),
                  "orange": ("set", 28, 1.0, 1.1), "white": ("set", 30, 0.35, 1.0), "glow": (255, 120, 40), "sparkle": (255, 190, 90)},
    "HornsShadow": {"kind": "Horns", "tcurve": (0.35, 1.0), "red": ("blend", (270, 0.6, 0.12), (283, 0.68, 0.6)), "gold": ("set", 270, 0.18, 1.0),
                    "orange": ("set", 285, 0.7, 1.0), "white": ("set", 275, 0.15, 1.0), "glow": (160, 100, 255), "sparkle": (215, 190, 255)},
    # attendance only (A23-77) - not sold
    "HaloSprout": {"kind": "Halo", "gold": ("set", 102, 0.68, 0.92), "orange": ("set", 95, 0.7, 0.95), "white": ("set", 100, 0.16, 1.0),
                   "red": ("set", 100, 0.6, 1.0), "glow": (150, 235, 120), "sparkle": (210, 255, 180)},
    "HornsSprout": {"kind": "Horns", "red": ("blend", (108, 0.75, 0.42), (90, 0.6, 0.95)), "gold": ("set", 70, 0.65, 1.0),
                    "orange": ("set", 60, 0.7, 1.0), "white": ("set", 95, 0.12, 1.0), "glow": (150, 235, 120), "sparkle": (210, 255, 180)},
    "HaloStarlight": {"kind": "Halo", "gold": ("set", 221, 0.72, 0.88), "orange": ("set", 44, 0.85, 1.0), "white": ("set", 220, 0.05, 1.0),
                      "red": ("set", 44, 0.85, 1.0), "emblem": ("set", 44, 0.88, 1.08), "vfloor": 0.3, "glow": (120, 150, 255), "sparkle": (255, 220, 120)},
    "HornsStarlight": {"kind": "Horns", "red": ("blend", (222, 0.78, 0.42), (219, 0.62, 0.86)), "gold": ("set", 44, 0.85, 1.05),
                       "orange": ("set", 44, 0.9, 1.05), "white": ("set", 44, 0.4, 1.0), "tips": ("set", 44, 0.85, 1.05),
                       "glow": (120, 150, 255), "sparkle": (255, 220, 120)},
    "HaloPlatinum": {"kind": "Halo", "gold": ("set", 214, 0.15, 1.1), "orange": ("set", 195, 0.4, 1.1), "white": ("set", 225, 0.04, 1.03),
                     "red": ("set", 195, 0.4, 1.1), "emblem": ("set", 195, 0.45, 1.15), "vfloor": 0.45, "glow": (210, 235, 255), "sparkle": (255, 255, 255)},
    "HornsPlatinum": {"kind": "Horns", "red": ("blend", (216, 0.16, 0.55), (214, 0.1, 0.98)), "gold": ("set", 222, 0.06, 1.15),
                      "orange": ("set", 195, 0.4, 1.12), "white": ("set", 220, 0.06, 1.0), "tips": ("set", 195, 0.42, 1.18),
                      "glow": (210, 235, 255), "sparkle": (255, 255, 255)},
}


def hsv(rgb):
    x = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV_FULL).astype(np.float32)
    return x[..., 0] / 255 * 360, x[..., 1] / 255, x[..., 2] / 255


def soft(x, lo, hi):
    return np.clip((x - lo) / max(hi - lo, 1e-6), 0, 1)


def hue_in(h, lo, hi, edge=5.0):
    c, half = (lo + hi) / 2, (hi - lo) / 2
    d = np.abs((h - c + 180) % 360 - 180)
    return np.clip((half - d) / edge + 0.5, 0, 1)


def classes(h, s, v):
    sat = soft(s, 0.22, 0.38) * soft(v, 0.12, 0.25)
    w = {"gold": sat * hue_in(h, 30, 66), "orange": sat * hue_in(h, 17, 30, 3), "red": sat * hue_in(h, -26, 17, 4),
         "white": soft(0.33 - s, 0, 0.12) * soft(v, 0.45, 0.6) * (1 - hue_in(h, -26, 17, 4) * soft(s, 0.2, 0.3))}  # wing beige shading too, not pale reds
    return w


def to_rgb(hh, ss, vv):
    x = np.stack([(hh % 360) / 360 * 255, np.clip(ss, 0, 1) * 255, np.clip(vv, 0, 1) * 255], -1).astype(np.uint8)
    return cv2.cvtColor(x, cv2.COLOR_HSV2RGB_FULL).astype(np.float32)


def recolor(rgb, theme, palette=False, masks=None):
    th = THEMES[theme]
    h, s, v = hsv(rgb)
    w = classes(h, s, v)
    if palette and th["kind"] == "Halo":
        # R1's ring is the palette's silver-white cell: treat it as the ring metal, not as a wing
        w["gold"] = np.maximum(w["gold"], w["white"])
        w["white"] = w["white"] * 0
    red = w["red"] > 0.5
    lo, hi = (np.percentile(v[red], 15), np.percentile(v[red], 90)) if red.sum() > 8 else (0.3, 0.9)
    t = np.clip((v - lo) / max(hi - lo, 1e-3), 0, 1)
    if "tcurve" in th:
        t = soft(t, *th["tcurve"])
    acc = np.zeros(rgb.shape, np.float32)
    wsum = np.zeros(h.shape, np.float32)
    for cls, wt in w.items():
        rule = th.get(cls)
        if not rule:
            continue
        if rule[0] == "set":
            _, H, S, Vm = rule
            ns = np.clip(S * (0.75 + 0.25 * soft(s, 0.2, 0.9)), 0, 1)
            if cls == "white":  # keep the white shading, only tint it
                ns = np.clip(s * 0.5 + S, 0, 1)
            c = to_rgb(np.full_like(h, H), ns, v * Vm)
        else:
            _, (h0, s0, v0), (h1, s1, v1) = rule
            c0 = to_rgb(np.full_like(h, h0), np.full_like(h, s0), np.full_like(h, v0))
            c1 = to_rgb(np.full_like(h, h1), np.full_like(h, s1), np.full_like(h, v1))
            shade = (0.85 + 0.3 * soft(v, 0.1, 1.0))[..., None]
            c = np.clip((c0 * (1 - t[..., None]) + c1 * t[..., None]) * shade, 0, 255)
        acc += c * wt[..., None]
        wsum += wt
    k = np.clip(wsum, 0, 1)
    mixed = np.where(wsum[..., None] > 1e-6, acc / np.maximum(wsum, 1e-6)[..., None], 0)
    out = rgb.astype(np.float32) * (1 - k[..., None]) + mixed * k[..., None]
    if "vfloor" in th:  # lift dark shading of a recoloured ring (dark navy read as black at 40 px)
        lift = th["vfloor"] * w["gold"][..., None]
        out = out * (1 - lift) + (out * 0 + 255 * th["vfloor"] + out * (1 - th["vfloor"])) * lift
    for key in ("emblem", "tips"):
        rule = th.get(key)
        if not rule or not masks or key not in masks:
            continue
        m = masks[key]
        if key == "emblem":  # only the gem / emblem pixels inside the front region (not the ring around R3's gems)
            m = m * np.maximum(w["gold"] * (1 if "R3" not in masks.get("name", "") else 0), w["white"])
        _, H, S, Vm = rule
        c = to_rgb(np.full_like(h, H), np.full_like(h, S), np.clip(v * Vm, 0, 1))
        out = out * (1 - m[..., None]) + c * m[..., None]
    return np.clip(out + 0.5, 0, 255).astype(np.uint8)


def _mix_h(a, b, w):
    d = ((b - a + 180) % 360) - 180
    return (a + d * w) % 360


def main(themes):
    meta = {}
    for theme in themes:
        th = THEMES[theme]
        d = SRC + theme + "/"
        os.makedirs(d, exist_ok=True)
        for r in range(1, 6):
            name = f"Acc_{th['kind']}R{r}"
            src = Image.open(SRC + f"{name}_base.png").convert("RGB")
            if r >= 3:
                src = src.resize((1024, 1024), Image.LANCZOS)
            masks = {"name": name}
            for mk in ("emblem", "tips"):
                mp = SRC + f"masks/{name}_{mk}.png"
                if mk == "emblem" and th.get("emblem_mask") and os.path.exists(SRC + f"masks/{name}_{th['emblem_mask']}.png"):
                    mp = SRC + f"masks/{name}_{th['emblem_mask']}.png"
                if r >= 3 and os.path.exists(mp):
                    masks[mk] = np.asarray(Image.open(mp).convert("L").resize(src.size, Image.BILINEAR)).astype(np.float32) / 255
            Image.fromarray(recolor(np.asarray(src), theme, palette=r <= 2, masks=masks)).save(d + f"{name}.png")
        meta[theme] = {"kind": th["kind"], "glow": th["glow"], "sparkle": th["sparkle"],
                       "files": [f"build/acctex/{theme}/Acc_{th['kind']}R{r}.png" for r in range(1, 6)]}
        print(theme, "ok")
    old = json.load(open(SRC + "themes.json")) if os.path.exists(SRC + "themes.json") else {}
    old.update(meta)
    json.dump(old, open(SRC + "themes.json", "w"), indent=1)


if __name__ == "__main__":
    main(sys.argv[1:] or list(THEMES))
