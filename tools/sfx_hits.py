"""
직업별 맞는 소리 후보 (소리 만들기, SPEC A23-113, 2026-10-10): 칼(베임) · 마법(펑/반짝) · 화살(퍽/박힘), 각각 보통·강·치명.
  py tools/sfx_hits.py            -> build/sfx_hits/cand/Hit<Blade|Magic|Arrow><Soft|Heavy|Crit>_<a|b>.wav  (18개, 직접 합성, 크레딧 0)
  py tools/sfx_hits.py sheet OUT.png
짧게 0.12~0.4초, 아이용(피·살점 느낌 없이 '툭/싹/뿅'), 폰 스피커에서 들리게 몸통 500 Hz~4 kHz, 전투 소리라 150 Hz 아래는 덜어냄.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import sfx_game as G  # noqa: E402

SR = G.SR
OUT = os.path.join(G.ROOT, "build", "sfx_hits", "cand")


def tone(freq, dur, shape="sine", decay=20.0, attack=0.002, bend=0.0):
    n = G.count(dur)
    t = G.secs(n)
    f = freq * (1 + bend * (t / dur))
    return G.osc(f, shape) * np.clip(t / attack, 0, 1) * np.exp(-t * decay)


def noise(dur, lo, hi, decay, seed, attack=0.001, sweep=None):
    """band-passed noise burst; sweep=(lo2, hi2) glides the band (a 'shk' that falls)"""
    r = np.random.default_rng(seed)
    n = G.count(dur)
    t = G.secs(n)
    x = r.standard_normal(n)
    if sweep is None:
        y = G.svf(G.svf(x, lo, 0.707, "hp"), hi, 0.707, "lp")
    else:
        h = n // 2
        a = G.svf(G.svf(x[:h], lo, 0.707, "hp"), hi, 0.707, "lp")
        b = G.svf(G.svf(x[h:], sweep[0], 0.707, "hp"), sweep[1], 0.707, "lp")
        xf = min(int(0.006 * SR), h // 2)  # a 6 ms cross-fade where the band changes (no click at the join)
        a2 = G.svf(G.svf(x[:h + xf], sweep[0], 0.707, "hp"), sweep[1], 0.707, "lp")[h:]
        ramp = np.linspace(0, 1, xf)
        b = b.copy()
        b[:xf] = b[:xf] * ramp + a2[:xf] * (1 - ramp)
        y = np.concatenate([a, b])
    return y * np.clip(t / attack, 0, 1) * np.exp(-t * decay)


def mix(parts):
    return G.mix(parts)


# ------------------------------------------------------------------ blade: a clean 'shk' cut
def blade(tier, v):
    s = 1 if v == "a" else 2
    if tier == "Soft":
        cut = noise(0.12, 1300, 4200, 28, 10 + s, sweep=(900, 2600))
        ring = tone(3300 if v == "a" else 2900, 0.12, decay=38) * 0.12
        return mix([(cut, 0, 1.0), (ring, 0.01, 1.0)])
    if tier == "Heavy":
        cut = noise(0.2, 1100, 4500, 17, 20 + s, sweep=(700, 2400))
        body = tone(520 if v == "a" else 440, 0.14, decay=24, bend=-0.3) * 0.55
        ring = tone(2600 if v == "a" else 2300, 0.2, decay=22) * 0.16
        return mix([(cut, 0, 1.0), (body, 0.0, 1.0), (ring, 0.015, 1.0)])
    cut = noise(0.26, 1100, 4800, 13, 30 + s, sweep=(700, 2600))
    body = tone(560, 0.16, decay=22, bend=-0.3) * 0.5
    ting = G.bell(2637 if v == "a" else 2349, 0.34, decay=9.0, partials=((1, 1.0, 1.0), (2.0, 0.3, 1.6))) * 0.3
    swish = noise(0.1, 1500, 5000, 20, 40 + s) * 0.35
    return mix([(swish, 0.0, 1.0), (cut, 0.06, 1.0), (body, 0.06, 1.0), (ting, 0.08, 1.0)])


# ------------------------------------------------------------------ magic: a bubbly 'pup' + sparkle
def magic(tier, v):
    s = 1 if v == "a" else 2
    if tier == "Soft":
        pop = tone(620 if v == "a" else 760, 0.11, "sine", decay=26, bend=0.7)
        return mix([(pop, 0, 0.9), (G.sparkle(0.12, 4, 3200, 5800, seed=50 + s, level=0.16), 0.03, 1.0)])
    if tier == "Heavy":
        pop = tone(430 if v == "a" else 520, 0.17, "sine", decay=17, bend=0.8) * 0.9
        pop2 = tone(900, 0.1, "sine", decay=30) * 0.35
        return mix([(pop, 0, 1.0), (pop2, 0.02, 1.0), (G.sparkle(0.22, 8, 3000, 6200, seed=60 + s, level=0.18), 0.05, 1.0)])
    pop = tone(470, 0.18, "sine", decay=15, bend=0.9) * 0.85
    notes = [(1175, 0.08), (1568, 0.15), (2093, 0.22)] if v == "a" else [(988, 0.08), (1319, 0.15), (1760, 0.22)]
    chime = [(G.bell(f, 0.22, decay=11.0, partials=((1, 1.0, 1.0), (2.0, 0.2, 2.0))), at, 0.45) for f, at in notes]
    return mix([(pop, 0, 1.0)] + chime + [(G.sparkle(0.3, 12, 3000, 6400, seed=70 + s, level=0.2), 0.1, 1.0)])


# ------------------------------------------------------------------ arrow: a woody 'thup' that sticks
def arrow(tier, v):
    s = 1 if v == "a" else 2
    if tier == "Soft":
        thk = tone(560 if v == "a" else 640, 0.1, "sine", decay=32, bend=-0.4)
        air = noise(0.07, 700, 2800, 40, 80 + s) * 0.5
        return mix([(thk, 0, 0.9), (air, 0, 1.0)])
    if tier == "Heavy":
        thk = tone(500 if v == "a" else 580, 0.16, "sine", decay=22, bend=-0.45) * 1.0
        knock = tone(780 if v == "a" else 900, 0.08, "sine", decay=50) * 0.4
        air = noise(0.1, 800, 3000, 30, 90 + s) * 0.4
        wob = tone(560, 0.22, "tri", decay=14, bend=0.0) * 0.12  # the shaft quivers (no string twang)
        return mix([(thk, 0, 1.0), (knock, 0.0, 1.0), (air, 0, 1.0), (wob, 0.04, 1.0)])
    thk = tone(520, 0.18, "sine", decay=20, bend=-0.45)
    crack = noise(0.05, 2000, 6500, 70, 100 + s) * 0.7
    knock = tone(950 if v == "a" else 1100, 0.09, "sine", decay=44) * 0.45
    wob = tone(600, 0.3, "tri", decay=11) * 0.14
    star = G.bell(2000, 0.25, decay=14.0, partials=((1, 1.0, 1.0),)) * 0.2
    return mix([(crack, 0, 1.0), (thk, 0.005, 1.0), (knock, 0.01, 1.0), (wob, 0.05, 1.0), (star, 0.03, 1.0)])


KINDS = {"Blade": blade, "Magic": magic, "Arrow": arrow}
TIERS = ("Soft", "Heavy", "Crit")
MAKERS = {}
for _k, _fn in KINDS.items():
    for _t in TIERS:
        for _v in ("a", "b"):
            MAKERS["Hit%s%s_%s" % (_k, _t, _v)] = (lambda fn=_fn, t=_t, v=_v: fn(t, v))


def render(fn):
    return G.finish(fn(), hp=150.0)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in MAKERS.items():
        x = render(fn)
        G.write_wav(os.path.join(OUT, name + ".wav"), x)
        m = G.metrics(x)
        print(name, m["sec"], "s centroid", m["centroidHz"], "phoneDrop", m["phoneDropDb"], "peak", m["peakDb"], "peakAt", m["peakAt"])


def sheet(path):
    from PIL import Image, ImageDraw
    from scipy.signal import spectrogram
    names = list(MAKERS)
    W, H = 600, 96
    cols = 2
    rows = (len(names) + cols - 1) // cols
    img = Image.new("RGB", (W * cols, H * rows), (250, 250, 250))
    d = ImageDraw.Draw(img)
    for i, name in enumerate(names):
        x = render(MAKERS[name])
        m = G.metrics(x)
        cx, cy = (i % cols) * W, (i // cols) * H
        d.text((cx + 6, cy + 2), "%s %.2fs c%dHz phone-%sdB pk%s" % (name, len(x) / SR, m["centroidHz"], m["phoneDropDb"], m["peakDb"]),
               fill=(0, 0, 0))
        hop = max(1, len(x) // (W // 2 - 14))
        n = len(x) // hop
        env_ = np.abs(x[:n * hop]).reshape(n, hop).max(axis=1)
        for k, v in enumerate(env_):
            px = cx + 6 + int(k / n * (W // 2 - 14))
            hh = int(v * (H / 2 - 14))
            d.line([(px, cy + H // 2 + 8 - hh), (px, cy + H // 2 + 8 + hh)], fill=(60, 90, 200))
        f, t, S = spectrogram(x, fs=SR, nperseg=256, noverlap=220)
        S = np.clip((10 * np.log10(S[:100] + 1e-13) + 110) / 60, 0, 1)
        im = Image.fromarray((255 - S[::-1] * 255).astype(np.uint8)).resize((W // 2 - 10, H - 18)).convert("RGB")
        img.paste(im, (cx + W // 2 + 4, cy + 16))
    img.save(path)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "sheet":
        sheet(sys.argv[2] if len(sys.argv) > 2 else os.path.join(G.ROOT, "build", "sfx_hits", "sheet.png"))
    else:
        main()
