"""
몬스터 종류별 죽는 소리 후보 (소리 만들기, 2026-10-10): 슬라임부터. 직접 합성(크레딧 0), 피·고통 소리 없이 귀엽게.
  DieSlime       작고 말랑한 '뽁/퐁' + 물방울 튐 (0.2~0.35 s)
  DieBigSlime    Slime Prince: 더 크고 둥근 '뿌웅-퐁' + 작은 반짝 (0.4 s쯤)
  DieFlowerSlime 꽃 슬라임: Slime에 꽃잎 같은 작은 종 한 번
  py tools/sfx_die.py            -> build/sfx_die/cand/<Key>_<a|b>.wav
  py tools/sfx_die.py sheet OUT.png
폰 스피커에서 안 줄게: 낮은 '뿌웅'도 400 Hz 위로(배음 포함).
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import sfx_game as G  # noqa: E402

SR = G.SR
OUT = os.path.join(G.ROOT, "build", "sfx_die", "cand")


def tone(freq, dur, shape="sine", decay=20.0, attack=0.002, bend=0.0):
    n = G.count(dur)
    t = G.secs(n)
    f = freq * (1 + bend * (t / dur))
    return G.osc(f, shape) * np.clip(t / attack, 0, 1) * np.exp(-t * decay)


def drops(dur, count, lo, hi, seed, level):
    """tiny water plinks: short sines that glide down a little"""
    r = np.random.default_rng(seed)
    out = np.zeros(G.count(dur + 0.06))
    for _ in range(count):
        at = int(r.uniform(0, dur) * SR)
        f = r.uniform(lo, hi)
        d = G.count(0.045)
        t = G.secs(d)
        x = np.sin(2 * np.pi * np.cumsum(f * (1 - 0.35 * t / 0.045)) / SR) * np.exp(-t * 70) * level * r.uniform(0.5, 1.0)
        out[at:at + d] += x
    return out


def slime(v):
    if v == "a":  # a bright 'pok': one quick rise, then three droplets
        pop = tone(420, 0.11, "sine", decay=24, bend=1.5)
        return G.mix([(pop, 0, 0.9), (tone(840, 0.07, "sine", decay=40), 0.0, 0.25), (drops(0.22, 4, 1600, 3200, 11, 0.7), 0.07, 1.0)])
    pop = tone(520, 0.14, "sine", decay=20, bend=1.1)  # a rounder 'pung' with a wobbling tail
    wob = tone(430, 0.2, "sine", decay=12, bend=-0.2) * (1 + 0.5 * np.sin(2 * np.pi * 26 * G.secs(G.count(0.2)))) * 0.35
    return G.mix([(pop, 0, 0.9), (wob, 0.05, 1.0), (drops(0.18, 2, 1400, 2800, 12, 0.35), 0.08, 1.0)])


def bigslime(v):
    if v == "a":  # 'puuung-pong': a big round rise, then a smaller 'pong', sparkle
        body = tone(380, 0.22, "sine", decay=11, bend=1.3) + 0.3 * tone(760, 0.22, "sine", decay=16, bend=1.3)
        pong = tone(560, 0.16, "sine", decay=18, bend=0.6)
        return G.mix([(body, 0, 0.9), (pong, 0.2, 0.7), (drops(0.3, 4, 1500, 3200, 21, 0.35), 0.1, 1.0),
                      (G.sparkle(0.25, 6, 3200, 5800, seed=22, level=0.12), 0.24, 1.0)])
    body = tone(340, 0.26, "sine", decay=13, bend=1.6) + 0.35 * tone(680, 0.26, "sine", decay=18, bend=1.6)
    pong = tone(480, 0.2, "sine", decay=20, bend=0.7)
    return G.mix([(body, 0, 0.9), (pong, 0.2, 0.65), (drops(0.2, 3, 1400, 3000, 23, 0.35), 0.12, 1.0),
                  (G.sparkle(0.2, 6, 3000, 6000, seed=24, level=0.12), 0.22, 1.0)])


def flowerslime(v):
    base = slime("a" if v == "a" else "b")
    petal = G.bell(1568.0 if v == "a" else 1397.0, 0.35, decay=9.0, partials=((1, 1.0, 1.0), (2.0, 0.2, 2.0))) * 0.22
    return G.mix([(base, 0, 1.0), (petal, 0.1, 1.0), (G.sparkle(0.2, 4, 3500, 6000, seed=31, level=0.1), 0.14, 1.0)])


MAKERS = {"DieSlime_a": lambda: slime("a"), "DieSlime_b": lambda: slime("b"),
          "DieBigSlime_a": lambda: bigslime("a"), "DieBigSlime_b": lambda: bigslime("b"),
          "DieFlowerSlime_a": lambda: flowerslime("a"), "DieFlowerSlime_b": lambda: flowerslime("b")}


def render(fn):
    return G.finish(fn(), hp=150.0)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in MAKERS.items():
        x = render(fn)
        G.write_wav(os.path.join(OUT, name + ".wav"), x)
        m = G.metrics(x)
        print(name, m["sec"], "s centroid", m["centroidHz"], "phoneDrop", m["phoneDropDb"], "peak", m["peakDb"])


def sheet(path):
    from PIL import Image, ImageDraw
    from scipy.signal import spectrogram
    names = list(MAKERS)
    W, H = 760, 120
    img = Image.new("RGB", (W * 2, H * len(names)), (250, 250, 250))
    d = ImageDraw.Draw(img)
    for row, name in enumerate(names):
        x = render(MAKERS[name])
        m = G.metrics(x)
        y0 = row * H
        d.text((8, y0 + 3), "%s %.2fs centroid %d Hz phoneDrop %s dB peak %s dB" % (name, len(x) / SR, m["centroidHz"], m["phoneDropDb"], m["peakDb"]),
               fill=(0, 0, 0))
        hop = max(1, len(x) // (W - 20))
        n = len(x) // hop
        env_ = np.abs(x[:n * hop]).reshape(n, hop).max(axis=1)
        for k, v in enumerate(env_):
            px = 10 + int(k / n * (W - 20))
            hh = int(v * (H / 2 - 20))
            d.line([(px, y0 + H // 2 + 8 - hh), (px, y0 + H // 2 + 8 + hh)], fill=(60, 90, 200))
        f, t, S = spectrogram(x, fs=SR, nperseg=512, noverlap=440)
        S = np.clip((10 * np.log10(S[:90] + 1e-13) + 110) / 60, 0, 1)
        im = Image.fromarray((255 - S[::-1] * 255).astype(np.uint8)).resize((W - 20, H - 24)).convert("RGB")
        img.paste(im, (W + 10, y0 + 20))
    img.save(path)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "sheet":
        sheet(sys.argv[2] if len(sys.argv) > 2 else os.path.join(G.ROOT, "build", "sfx_die", "sheet.png"))
    else:
        main()
