# moved from build/horns_bright (2026-10-07): estimates for the Horns town brightness sheet (quality 7)
"""Estimate the Horns town look under new ZoneLook / texture values from a real capture (linear-light ratios).
Not a replacement for a Studio capture: no tone mapping, a fixed sun weight. Same model for before and after."""
import json
import numpy as np
from PIL import Image

def lin(c): return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
def gam(c): return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.clip(c, 0, None) ** (1 / 2.4) - 0.055)
def luma(g): return 0.2126 * g[..., 0] + 0.7152 * g[..., 1] + 0.0722 * g[..., 2]
def relL(g): l = lin(g); return 0.2126 * l[..., 0] + 0.7152 * l[..., 1] + 0.0722 * l[..., 2]

SKY = {"Neutral": dict(B=2.0, Amb=(110, 108, 106), Out=(128, 126, 124), Exp=-0.2),
       "Eclipse": dict(B=1.4, Amb=(100, 62, 78), Out=(115, 76, 92), Exp=0.45)}
S_SUN = 0.5  # share of the sun term in the ground light (the sun is low-ish at ClockTime 14.2/16.8)
# night (Eclipse, ClockTime 0.5): no sun term, and a calibration gain so the meadow day capture turns into the real
# night meadow capture (ground luma 0.210, build/zone_look/night_meadow.jpeg)
NIGHT_GAIN = 0.575

def light(sky, z):
    s = SKY[sky]
    b = s["B"] * (max(z["Bright"], 0.95) if sky == "Eclipse" else z["Bright"])
    out = np.array(s["Out"]) / 255 * np.array(z["Amb"])
    irr = (b * S_SUN + out) if sky == "Neutral" else out * NIGHT_GAIN  # per channel
    night = z.get("NightExp", 0) if sky == "Eclipse" else 0  # proposed ZoneLook key: extra exposure under Eclipse
    return irr * 2 ** (s["Exp"] + z["Exp"] + night), np.array(z["Tint"]) / 255, z["Con"], z["CC"]

CUR = dict(Amb=(1.12, 0.86, 0.9), Bright=0.88, Exp=0.08, Tint=(255, 218, 214), Con=0.08, CC=0)

def simulate(img, sky_mask, z, alb_ratio, sky="Neutral"):
    g = img.copy()
    i0, t0, c0, cc0 = light("Neutral", CUR)
    i1, t1, c1, cc1 = light(sky, z)
    pre = np.clip((g - 0.5) / (1 + c0) + 0.5 - cc0, 0, 1)  # undo the current ZoneTint contrast / brightness
    L = lin(pre)
    ratio = (i1 / i0) * (t1 / t0)
    L2 = L * ratio[None, None, :]
    L2 = np.where(sky_mask[..., None], L, L2 * alb_ratio[None, None, :])  # sky keeps its look
    post = gam(np.clip(L2, 0, 1))
    post = np.where(sky_mask[..., None], g, np.clip((post - 0.5) * (1 + c1) + 0.5 + cc1, 0, 1))
    if sky == "Eclipse":
        # the day sky of the capture becomes a dark red night sky (top (15,20,30) -> horizon (60,30,25), like the real
        # night captures), so the night mean is not lifted by a blue day sky
        H = g.shape[0]
        t = np.clip(np.arange(H) / (H * 0.45), 0, 1)[:, None, None]
        night_sky = (np.array([15, 20, 30]) * (1 - t) + np.array([60, 30, 25]) * t) / 255
        post = np.where(sky_mask[..., None], np.broadcast_to(night_sky, g.shape), post)
    return post

if __name__ == "__main__":
    img = np.asarray(Image.open("build/zone_look/horns_town.jpeg").convert("RGB")).astype(np.float32) / 255
    H, W = img.shape[:2]
    yy = np.arange(H)[:, None] * np.ones((1, W))
    sky = (img[..., 2] > img[..., 0] + 0.08) & (yy < H * 0.45)
    ground = (yy > H * 0.55)
    tex0 = lin(np.asarray(Image.open("art/ui/Tex_Basalt_FF.png").convert("RGB")).astype(np.float32) / 255).reshape(-1, 3).mean(0)
    out = {}
    variants = {
        "V0 now": (CUR, None),
        "V1 light only": (dict(Amb=(1.18, 0.98, 1.0), Bright=1.0, Exp=0.25, Tint=(255, 236, 230), Con=0.03, CC=0.03), None),
        "V2 light + tile k1.45": (dict(Amb=(1.18, 0.98, 1.0), Bright=1.0, Exp=0.25, Tint=(255, 236, 230), Con=0.03, CC=0.03), "build/horns_bright/Tex_Basalt_k1.45.png"),
        "V3 light + tile k1.6": (dict(Amb=(1.18, 0.98, 1.0), Bright=1.0, Exp=0.25, Tint=(255, 236, 230), Con=0.03, CC=0.03), "build/horns_bright/Tex_Basalt_k1.6.png"),
        "V4 V2 + NightExp 0.8": (dict(Amb=(1.18, 0.98, 1.0), Bright=1.0, Exp=0.25, Tint=(255, 236, 230), Con=0.03, CC=0.03, NightExp=0.8), "build/horns_bright/Tex_Basalt_k1.45.png"),
        "V5 V2 + NightExp 1.1": (dict(Amb=(1.18, 0.98, 1.0), Bright=1.0, Exp=0.25, Tint=(255, 236, 230), Con=0.03, CC=0.03, NightExp=1.1), "build/horns_bright/Tex_Basalt_k1.45.png"),
        "V6 V2 + NightExp 1.6": (dict(Amb=(1.18, 0.98, 1.0), Bright=1.0, Exp=0.25, Tint=(255, 236, 230), Con=0.03, CC=0.03, NightExp=1.6), "build/horns_bright/Tex_Basalt_k1.45.png"),
        "V7 V2 + NightExp 1.9": (dict(Amb=(1.18, 0.98, 1.0), Bright=1.0, Exp=0.25, Tint=(255, 236, 230), Con=0.03, CC=0.03, NightExp=1.9), "build/horns_bright/Tex_Basalt_k1.45.png"),
    }
    AV = {"skin": (234, 184, 146), "white shirt": (240, 240, 240), "blue": (13, 105, 172), "red": (200, 30, 40), "gray": (128, 128, 128), "black": (35, 35, 35)}
    for name, (z, tex) in variants.items():
        ar = np.ones(3) if tex is None else lin(np.asarray(Image.open(tex).convert("RGB")).astype(np.float32) / 255).reshape(-1, 3).mean(0) / tex0
        for sky_name in ("Neutral", "Eclipse"):
            sim = simulate(img, sky, z, ar, sky_name)
            lum = luma(sim)
            gL = relL(sim)[ground].mean()
            # avatar under the same light as the ground (albedo x light ratio of a white surface)
            i1, t1, c1, cc1 = light(sky_name, z)
            i0, t0, c0, cc0 = light("Neutral", CUR)
            white_ground_ratio = None
            row = {"mean": round(float(lum.mean()), 3), "ground": round(float(lum[ground].mean()), 3), "groundRelL": round(float(gL), 4)}
            # contrast: avatar albedo lit like the ground (ground lit colour / ground albedo = light), WCAG ratio
            g_alb = (lin(np.asarray(Image.open(tex or "art/ui/Tex_Basalt_FF.png").convert("RGB")).astype(np.float32) / 255)).reshape(-1, 3).mean(0)
            g_alb_L = 0.2126 * g_alb[0] + 0.7152 * g_alb[1] + 0.0722 * g_alb[2]
            k = gL / max(g_alb_L, 1e-5)  # light gain on a surface
            cr = {}
            for an, c in AV.items():
                aL = lin(np.array(c) / 255)
                aL = 0.2126 * aL[0] + 0.7152 * aL[1] + 0.0722 * aL[2]
                Lav = min(1.0, aL * k)
                hi, lo = max(Lav, gL), min(Lav, gL)
                cr[an] = round((hi + 0.05) / (lo + 0.05), 2)
            row["contrast"] = cr
            out[f"{name} | {sky_name}"] = row
            Image.fromarray((np.clip(sim, 0, 1) * 255).astype(np.uint8)).save(f"build/horns_bright/sim_{name.split()[0]}_{sky_name}.jpg", quality=88)
    json.dump(out, open("build/horns_bright/sim_values.json", "w"), indent=1)
    for k2, v in out.items():
        print(k2, v)
