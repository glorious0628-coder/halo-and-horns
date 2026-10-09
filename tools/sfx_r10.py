"""
10차 효과음 후보 (소리 만들기, 2026-10-10): 마을 이동 판 Warp / WarpIn, 이스터 에그 SecretFound. 모두 직접 합성(크레딧 0).
  py tools/sfx_r10.py            -> build/sfx_r10/cand/<Key>_<a|b>.wav  (48 kHz 모노, tools/sfx_game.finish 로 크기 맞춤)
  py tools/sfx_check.py build/sfx_r10/cand --out build/sfx_r10/check   (모양 시트)
소리 규칙(sound_session_handoff): 아이용, 무섭지 않게, 종교 느낌(교회 종) 없음, 폰 스피커에서 들리게 500 Hz~4 kHz에 몸통.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import sfx_game as G  # noqa: E402

SR = G.SR
OUT = os.path.join(G.ROOT, "build", "sfx_r10", "cand")


def sweep(f0, f1, dur, shape="sine", curve=1.0):
    n = G.count(dur)
    u = np.linspace(0, 1, n) ** curve
    f = f0 * (f1 / f0) ** u
    return G.osc(f, shape)


def airy(dur, f0, f1, seed, q=1.0):
    """band-passed noise whose centre sweeps f0 -> f1 (a soft 'shhhw')"""
    r = np.random.default_rng(seed)
    n = G.count(dur)
    x = r.standard_normal(n)
    u = np.linspace(0, 1, n)
    fc = f0 * (f1 / f0) ** u
    lo = G.svf(x, float(np.median(fc)) * 0.6, 0.707, "hp")
    out = G.svf(lo, float(np.median(fc)) * 1.8, 0.707, "lp")
    # slow amplitude arc: rises then falls
    arc = np.sin(np.pi * u) ** 1.5
    return out * arc


def note(freq, dur=0.35, decay=7.0, soft=True):
    parts = ((1, 1.0, 1.0), (2.0, 0.25, 1.8), (3.0, 0.08, 2.4)) if soft else None
    return G.bell(freq, dur, decay=decay, partials=parts) if soft else G.bell(freq, dur, decay=decay)


def warp_a():
    """leave: airy rise + a gliding sine 420 -> 1500 Hz, tiny sparkle at the top"""
    dur = 0.62
    glide = sweep(420, 1500, dur, curve=1.4) * G.env(G.count(dur), attack=0.06, decay=2.2) * 0.45
    air = airy(dur, 700, 5200, seed=3) * 0.55
    top = G.mix([(note(1568, 0.3, 9.0), 0.40, 0.55), (G.sparkle(0.25, 8, 3000, 6500, seed=5, level=0.18), 0.42, 1.0)])
    return G.mix([(glide, 0, 1.0), (air, 0, 1.0), (top, 0, 1.0)])


def warp_b():
    """leave: a quick pentatonic climb of soft bells over a breath of air"""
    freqs = [523.25, 659.25, 783.99, 1046.5, 1318.5]
    parts = [(note(f, 0.28, 8.0), 0.07 * i, 0.75) for i, f in enumerate(freqs)]
    parts.append((airy(0.55, 900, 4200, seed=8) * 0.35, 0.0, 1.0))
    parts.append((G.sparkle(0.2, 6, 3500, 6000, seed=9, level=0.14), 0.30, 1.0))
    return G.mix(parts)


def warpin_a():
    """arrive: a falling glide 1600 -> 520 Hz with air, ends in a soft round 'bloop'"""
    dur = 0.5
    glide = sweep(1600, 520, dur, curve=0.8) * G.env(G.count(dur), attack=0.01, decay=2.6) * 0.42
    air = airy(dur, 4200, 900, seed=4) * 0.45
    land = note(523.25, 0.32, 7.0) * 0.8
    return G.mix([(glide, 0, 1.0), (air, 0, 1.0), (land, 0.34, 0.9), (G.sparkle(0.2, 5, 2800, 5200, seed=6, level=0.12), 0.38, 1.0)])


def warpin_b():
    """arrive: sparkle burst that settles into two falling bells"""
    parts = [(G.sparkle(0.28, 10, 3000, 6500, seed=11, level=0.16), 0.0, 1.0),
             (note(1318.5, 0.3, 8.0), 0.10, 0.6), (note(880.0, 0.34, 7.5), 0.20, 0.7),
             (airy(0.4, 3800, 1000, seed=12) * 0.28, 0.0, 1.0)]
    return G.mix(parts)


def secret_a():
    """found a secret: three rising soft bells (E5 G5 B5, a gentle major seventh) + a glitter tail"""
    freqs = [659.25, 783.99, 987.77, 1318.5]
    parts = [(note(f, 0.45, 6.0), 0.11 * i, 0.8) for i, f in enumerate(freqs)]
    parts.append((G.sparkle(0.5, 14, 3000, 6800, seed=21, level=0.16), 0.30, 1.0))
    return G.mix(parts)


def secret_b():
    """found a secret: a music-box 'tinkle' (two quick notes, an octave answer) with a small shimmer"""
    box = lambda f, d: G.bell(f, d, decay=11.0, partials=((1, 1.0, 1.0), (3.0, 0.22, 2.0), (5.0, 0.07, 2.8)))
    parts = [(box(1174.7, 0.30), 0.0, 0.75), (box(1568.0, 0.30), 0.12, 0.75), (box(2093.0, 0.42), 0.25, 0.6),
             (G.sparkle(0.45, 10, 3200, 6500, seed=22, level=0.13), 0.30, 1.0)]
    return G.mix(parts)


MAKERS = {"Warp_a": warp_a, "Warp_b": warp_b, "WarpIn_a": warpin_a, "WarpIn_b": warpin_b,
          "SecretFound_a": secret_a, "SecretFound_b": secret_b}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in MAKERS.items():
        x = G.finish(fn(), hp=100.0)
        G.write_wav(os.path.join(OUT, name + ".wav"), x)
        m = G.metrics(x)
        print(name, m["sec"], "s", "centroid", m["centroidHz"], "phoneDrop", m["phoneDropDb"], "peak", m["peakDb"])


if __name__ == "__main__":
    main()


def sheet(path):
    """one PNG: for every candidate the waveform, a 0-8 kHz spectrogram and the numbers (no spec file needed)"""
    from PIL import Image, ImageDraw
    from scipy.signal import spectrogram
    names = list(MAKERS)
    W, H = 760, 150
    img = Image.new("RGB", (W * 2, H * len(names)), (250, 250, 250))
    d = ImageDraw.Draw(img)
    for row, name in enumerate(names):
        x = G.finish(MAKERS[name](), hp=100.0)
        m = G.metrics(x)
        y0 = row * H
        d.text((8, y0 + 3), "%s  %.2fs  centroid %d Hz  phoneDrop %s dB  peak %s dB  pitch %s" % (
            name, m["sec"], m["centroidHz"], m["phoneDropDb"], m["peakDb"], m["pitch"]), fill=(0, 0, 0))
        hop = max(1, len(x) // (W - 20))
        n = len(x) // hop
        env_ = np.abs(x[:n * hop]).reshape(n, hop).max(axis=1)
        for k, v in enumerate(env_):
            px = 10 + int(k / n * (W - 20))
            hh = int(v * (H / 2 - 22))
            d.line([(px, y0 + H // 2 + 8 - hh), (px, y0 + H // 2 + 8 + hh)], fill=(60, 90, 200))
        f, t, S = spectrogram(x, fs=SR, nperseg=1024, noverlap=900)
        S = 10 * np.log10(S[:170] + 1e-12)
        S = np.clip((S + 110) / 60, 0, 1)
        im = Image.fromarray((255 - S[::-1] * 255).astype(np.uint8)).resize((W - 20, H - 28)).convert("RGB")
        img.paste(im, (W + 10, y0 + 22))
    img.save(path)


if len(sys.argv) > 1 and sys.argv[1] == "sheet":
    sheet(sys.argv[2] if len(sys.argv) > 2 else os.path.join(G.ROOT, "build", "sfx_r10", "sheet.png"))
