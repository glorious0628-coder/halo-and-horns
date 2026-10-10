"""
NPC 말소리 블립 후보 (소리 만들기, 2026-10-10): TalkToNpc 대화창이 열릴 때 나는 짧은 '뿅'. 목소리 없음, 직접 합성(크레딧 0).
  Bright  = 밝고 높게 (빛 쪽 안내자)      Grim = 낮고 단단하게 (뿔 쪽 안내자)      Folk = 중간 (주민)
  py tools/sfx_blips.py            -> build/sfx_blips/cand/<Key>_<a|b>.wav
  py tools/sfx_blips.py sheet OUT.png
a = 2음 ('뿅-뽕'), b = 3음 (더 수다스러움). 0.14~0.3초, 몸통 400 Hz~3 kHz (폰 스피커에서 들림), 귀에 거슬리지 않게 부드러운 시작.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import sfx_game as G  # noqa: E402

SR = G.SR
OUT = os.path.join(G.ROOT, "build", "sfx_blips", "cand")


def tone(freq, dur, shape="tri", decay=14.0, attack=0.004, bend=0.0, vib=0.0):
    n = G.count(dur)
    t = G.secs(n)
    f = freq * (1 + bend * (t / dur)) * (1 + vib * np.sin(2 * np.pi * 42 * t))
    x = G.osc(f, shape)
    return x * np.clip(t / attack, 0, 1) * np.exp(-t * decay)


def bright(var):
    # glassy upper-register blip: sine + 3rd harmonic shimmer, rising
    seq = [(1174.7, 0.0), (1568.0, 0.07)] if var == "a" else [(1046.5, 0.0), (1318.5, 0.055), (1760.0, 0.11)]
    parts = []
    for f, at in seq:
        x = G.mix([(tone(f, 0.12, "sine", decay=16, bend=0.04), 0.0, 1.0), (tone(f * 3, 0.08, "sine", decay=26), 0.0, 0.25)])
        parts.append((x, at, 0.8))
    return G.mix(parts)


def grim(var):
    # low, firm 'dum-dum': a soft square/pulse with a short pitch drop, no fierce edge
    seq = [(329.6, 0.0), (261.6, 0.085)] if var == "a" else [(293.7, 0.0), (293.7, 0.07), (220.0, 0.14)]
    parts = []
    for f, at in seq:
        x = tone(f, 0.16, "pulse", decay=17, bend=-0.07)
        x = G.svf(x, 3200, 0.707, "lp")
        x = G.mix([(x, 0.0, 1.0), (tone(f * 2, 0.12, "sine", decay=20), 0.0, 0.7), (tone(f * 4, 0.1, "sine", decay=22), 0.0, 0.55)])
        parts.append((x, at, 0.8))
    return G.mix(parts)


def folk(var):
    # middle voice: a wooden triangle 'bu-pu'
    seq = [(587.3, 0.0), (698.5, 0.075)] if var == "a" else [(523.25, 0.0), (659.25, 0.065), (587.3, 0.13)]
    parts = []
    for f, at in seq:
        x = tone(f, 0.13, "tri", decay=18, bend=0.03)
        x = G.svf(x, 2600, 0.707, "lp")
        parts.append((x, at, 0.85))
    return G.mix(parts)


MAKERS = {"BlipBright_a": lambda: bright("a"), "BlipBright_b": lambda: bright("b"),
          "BlipGrim_a": lambda: grim("a"), "BlipGrim_b": lambda: grim("b"),
          "BlipFolk_a": lambda: folk("a"), "BlipFolk_b": lambda: folk("b")}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in MAKERS.items():
        x = G.finish(fn(), hp=150.0)
        G.write_wav(os.path.join(OUT, name + ".wav"), x)
        m = G.metrics(x)
        print(name, m["sec"], "s centroid", m["centroidHz"], "phoneDrop", m["phoneDropDb"], "peak", m["peakDb"], "pitch", m["pitch"])


def sheet(path):
    from PIL import Image, ImageDraw
    from scipy.signal import spectrogram
    W, H = 760, 140
    img = Image.new("RGB", (W * 2, H * len(MAKERS)), (250, 250, 250))
    d = ImageDraw.Draw(img)
    for row, (name, fn) in enumerate(MAKERS.items()):
        x = G.finish(fn(), hp=150.0)
        m = G.metrics(x)
        y0 = row * H
        d.text((8, y0 + 3), "%s %.2fs centroid %d Hz phoneDrop %s dB peak %s dB pitch %s" % (
            name, m["sec"], m["centroidHz"], m["phoneDropDb"], m["peakDb"], m["pitch"]), fill=(0, 0, 0))
        hop = max(1, len(x) // (W - 20))
        n = len(x) // hop
        env_ = np.abs(x[:n * hop]).reshape(n, hop).max(axis=1)
        for k, v in enumerate(env_):
            px = 10 + int(k / n * (W - 20))
            hh = int(v * (H / 2 - 22))
            d.line([(px, y0 + H // 2 + 8 - hh), (px, y0 + H // 2 + 8 + hh)], fill=(60, 90, 200))
        f, t, S = spectrogram(x, fs=SR, nperseg=512, noverlap=450)
        S = np.clip((10 * np.log10(S[:90] + 1e-12) + 110) / 60, 0, 1)
        im = Image.fromarray((255 - S[::-1] * 255).astype(np.uint8)).resize((W - 20, H - 28)).convert("RGB")
        img.paste(im, (W + 10, y0 + 22))
    img.save(path)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "sheet":
        sheet(sys.argv[2] if len(sys.argv) > 2 else os.path.join(G.ROOT, "build", "sfx_blips", "sheet.png"))
    else:
        main()
