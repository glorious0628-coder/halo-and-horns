"""
먼 데서 들리는 맑은 소리 (소리 만들기, 2026-10-10): 빛 마을 가끔 나는 '먼 종소리' 대신 교회 종이 아닌 글로켄슈필·풍경 3음(검수 A23-105 / 소리 규칙).
  py tools/sfx_distant.py        -> build/sfx_distant/cand/DistantChime_<a|b>.wav (모노, 3~4초, 아주 작게, 먼 느낌 = 고음 깎기 + 잔향)
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import sfx_game as G  # noqa: E402

SR = G.SR
OUT = os.path.join(G.ROOT, "build", "sfx_distant", "cand")


def reverb(x, secs=2.2, wet=0.55, seed=3):
    r = np.random.default_rng(seed)
    n = int(secs * SR)
    t = np.arange(n) / SR
    ir = r.standard_normal(n) * np.exp(-t * 2.4)
    ir = G.svf(ir, 3200, 0.707, "lp")
    ir /= np.abs(ir).sum() ** 0.5 + 1e-9
    from scipy.signal import fftconvolve
    y = fftconvolve(x, ir)[:len(x) + n // 2]
    xx = np.concatenate([x, np.zeros(len(y) - len(x))])
    return xx * (1 - wet) + y / (np.abs(y).max() + 1e-9) * np.abs(xx).max() * wet * 1.2


def glock(f, d, decay):
    return G.bell(f, d, decay=decay, partials=((1, 1.0, 1.0), (2.76, 0.12, 2.2), (5.4, 0.04, 3.5)))


def chime_a():
    notes = [(1318.5, 0.0), (1046.5, 0.55), (784.0, 1.1)]  # E6 C6 G5, slowly falling: a tower playing three soft bars
    x = np.zeros(int(3.2 * SR))
    for f, at in notes:
        g = glock(f, 1.4, 3.2)
        i = int(at * SR)
        x[i:i + len(g)] += g * 0.6
    return reverb(G.svf(x, 3000, 0.707, "lp"))


def chime_b():
    notes = [(987.8, 0.0), (1318.5, 0.5)]  # B5 E6 (two soft wind-chime tubes, rising)
    x = np.zeros(int(3.0 * SR))
    for f, at in notes:
        g = G.bell(f, 1.6, decay=3.0, partials=((1, 1.0, 1.0), (2.0, 0.18, 1.6)))
        i = int(at * SR)
        x[i:i + len(g)] += g * 0.6
    return reverb(G.svf(x, 2600, 0.707, "lp"), wet=0.6, seed=4)


MAKERS = {"DistantChime_a": chime_a, "DistantChime_b": chime_b}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in MAKERS.items():
        x = fn()
        x = G.finish(x, hp=200.0)
        x = x * 10 ** (-9 / 20)  # a distant, quiet one-shot (the game Volume does the rest)
        G.write_wav(os.path.join(OUT, name + ".wav"), x)
        m = G.metrics(x)
        print(name, m["sec"], "s centroid", m["centroidHz"], "phoneDrop", m["phoneDropDb"], "peak", m["peakDb"])


if __name__ == "__main__":
    main()
