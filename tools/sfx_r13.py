"""
13차 효과음 후보 (소리 만들기, 2026-10-10): 작은 마을 소리 + 펫 소리 + 마름모 톡. 모두 직접 합성(크레딧 0).
  LanternOn  저녁 등불 켜질 때 부드러운 '띵'      DoorOpen  마을 문 열림(나무 '툭' + 살짝 삐걱)
  RainRoof   지붕 아래서 듣는 빗소리(먹먹, 약하게, 25 s 루프)
  PetCall    펫 따라오게(뾰로 2음)   PetStow 넣어 두기(뽁)   PetLevel 펫 레벨 오름(작은 3음 팡파르)
  DiamondTick 마름모 목표 갱신 '톡'
  py tools/sfx_r13.py            -> build/sfx_r13/cand/<Key>_<a|b>.wav (48 kHz 모노)
  py tools/sfx_r13.py sheet OUT.png
규칙: 아이용, 종교 느낌(교회 종) 없음, 폰 스피커에서 들리게 500 Hz~4 kHz에 몸통, 자주 나는 소리는 짧게.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import sfx_game as G  # noqa: E402
import sfx_ambient as A  # noqa: E402

SR = G.SR
OUT = os.path.join(G.ROOT, "build", "sfx_r13", "cand")


def tone(freq, dur, shape="sine", decay=12.0, attack=0.004, bend=0.0):
    n = G.count(dur)
    t = G.secs(n)
    f = freq * (1 + bend * (t / dur))
    return G.osc(f, shape) * np.clip(t / attack, 0, 1) * np.exp(-t * decay)


def soft_bell(f, dur, decay):
    return G.bell(f, dur, decay=decay, partials=((1, 1.0, 1.0), (2.0, 0.22, 1.7), (3.0, 0.06, 2.4)))


def lantern_a():
    # one warm 'ting' (G5) with a quiet octave shimmer, long soft tail
    return G.mix([(soft_bell(784.0, 0.9, 5.0), 0.0, 1.0), (soft_bell(1568.0, 0.5, 9.0), 0.0, 0.18),
                  (G.sparkle(0.3, 5, 3000, 5500, seed=3, level=0.10), 0.02, 1.0)])


def lantern_b():
    # a glowing 'ting-ing': two soft bells (E5 -> B5) a beat apart, like a flame catching
    return G.mix([(soft_bell(659.25, 0.6, 6.0), 0.0, 0.9), (soft_bell(987.77, 0.8, 5.0), 0.11, 0.85),
                  (G.sparkle(0.35, 6, 3200, 5800, seed=4, level=0.10), 0.12, 1.0)])


def door_a():
    # wooden thunk of the latch + a short, soft rising creak (no horror: the creak is a quick gentle glide)
    th = G.mix([(tone(420, 0.12, "sine", decay=34, bend=-0.3), 0.0, 0.9),
                (G.svf(np.random.default_rng(5).standard_normal(G.count(0.05)), 2600, 0.707, "lp") * np.exp(-G.secs(G.count(0.05)) * 90), 0.0, 0.5)])
    creak = tone(560, 0.32, "tri", decay=3.2, attack=0.05, bend=0.5) * 0.35
    creak = G.svf(creak, 1500, 0.707, "lp")
    return G.mix([(th, 0.0, 1.0), (creak, 0.06, 1.0)])


def door_b():
    # a gentle wooden knock-and-swing: two soft taps then a bright little 'whoo' of air
    tap = lambda f, at: (tone(f, 0.09, "sine", decay=40, bend=-0.2), at, 0.8)
    air = A.band(np.random.default_rng(6).standard_normal(G.count(0.3)), 700, 2600) * np.sin(np.linspace(0, np.pi, G.count(0.3))) ** 2 * 0.25
    return G.mix([tap(440, 0.0), tap(520, 0.09), (air, 0.12, 1.0)])


def pet_call_a():
    # 'pyo-ro': two quick rising peeps (a happy call), triangle with a little glide
    return G.mix([(tone(880, 0.11, "tri", decay=14, bend=0.3), 0.0, 0.8), (tone(1175, 0.16, "tri", decay=12, bend=0.25), 0.09, 0.8)])


def pet_call_b():
    # a bright 'pip-pip-pii' three-peep call
    return G.mix([(tone(1047, 0.07, "sine", decay=22), 0.0, 0.8), (tone(1047, 0.07, "sine", decay=22), 0.08, 0.8),
                  (tone(1397, 0.16, "sine", decay=14, bend=0.12), 0.16, 0.85)])


def pet_stow_a():
    # a soft 'pop' pulled inward: a quick falling glide with a round tap
    return G.mix([(tone(900, 0.12, "sine", decay=20, bend=-0.55), 0.0, 0.8), (tone(420, 0.1, "sine", decay=34), 0.1, 0.6)])


def pet_stow_b():
    # 'ppup': a rising blip then a closing tick, squeaky-clean
    return G.mix([(tone(520, 0.08, "tri", decay=26, bend=0.7), 0.0, 0.8), (tone(1000, 0.05, "sine", decay=50), 0.07, 0.5)])


def pet_level_a():
    # a tiny three-note fanfare (C6 E6 G6, music-box) with sparkle: much smaller than the player's LevelUp
    box = lambda f, d: G.bell(f, d, decay=10.0, partials=((1, 1.0, 1.0), (3.0, 0.2, 2.0)))
    return G.mix([(box(1046.5, 0.3), 0.0, 0.75), (box(1318.5, 0.3), 0.09, 0.75), (box(1568.0, 0.5), 0.18, 0.8),
                  (G.sparkle(0.4, 8, 3200, 6200, seed=7, level=0.12), 0.22, 1.0)])


def pet_level_b():
    # pet 'woo!': a rising happy glide + a bell at the top
    return G.mix([(tone(700, 0.3, "tri", decay=5, bend=1.1, attack=0.02), 0.0, 0.7), (soft_bell(1568.0, 0.6, 6.0), 0.22, 0.8),
                  (G.sparkle(0.35, 7, 3000, 6000, seed=8, level=0.12), 0.26, 1.0)])


def diamond_a():
    return tone(1500, 0.08, "sine", decay=55, bend=-0.05) * 0.8


def diamond_b():
    return G.mix([(tone(1100, 0.06, "sine", decay=60), 0.0, 0.7), (tone(1650, 0.07, "sine", decay=55), 0.035, 0.6)])


def rain_roof(variant):
    """rain heard from under a roof: the sheet is muffled (low-passed ~2.2 kHz), the drops become soft 'tup's on wood"""
    import numpy as _n
    rng = _n.random.default_rng(81 if variant == "a" else 82)
    n = int(A.SECONDS * SR) + A.XF
    white = rng.standard_normal(n)
    sheet = A.lowp(A.band(white, 400, 4000), 2200, 2) * A.slow(rng, n, 0.15, 0.2)
    drops = _n.zeros(n)
    count = int((A.SECONDS + 2) * (10 if variant == "a" else 22))
    for _ in range(count):
        pos = int(rng.uniform(0, n - 3000))
        f = rng.uniform(180, 520)
        tt = _n.arange(2000) / SR
        drops[pos:pos + 2000] += _n.sin(2 * _n.pi * f * tt * (1 - 0.3 * tt * 20)) * _n.exp(-tt * rng.uniform(55, 120)) * rng.uniform(0.2, 0.7)
    y = sheet * 0.4 + drops * sheet.std() * 3.0
    return A.finish(y, -33.0)


ONESHOT = {"LanternOn_a": lantern_a, "LanternOn_b": lantern_b, "DoorOpen_a": door_a, "DoorOpen_b": door_b,
           "PetCall_a": pet_call_a, "PetCall_b": pet_call_b, "PetStow_a": pet_stow_a, "PetStow_b": pet_stow_b,
           "PetLevel_a": pet_level_a, "PetLevel_b": pet_level_b, "DiamondTick_a": diamond_a, "DiamondTick_b": diamond_b}
LOOPS = {"RainRoof_a": lambda: rain_roof("a"), "RainRoof_b": lambda: rain_roof("b")}


def finish_one(fn):
    return G.finish(fn(), hp=100.0)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in ONESHOT.items():
        x = finish_one(fn)
        G.write_wav(os.path.join(OUT, name + ".wav"), x)
        m = G.metrics(x)
        print(name, m["sec"], "s centroid", m["centroidHz"], "phoneDrop", m["phoneDropDb"], "peak", m["peakDb"])
    for name, fn in LOOPS.items():
        x = fn()
        G.write_wav(os.path.join(OUT, name + ".wav"), x)
        print(name, "%.1fs loop" % (len(x) / SR), "seam", A.seam(x))


def sheet(path):
    from PIL import Image, ImageDraw
    from scipy.signal import spectrogram
    items = [(n, finish_one(f)) for n, f in ONESHOT.items()] + [(n, f()) for n, f in LOOPS.items()]
    W, H = 760, 120
    img = Image.new("RGB", (W * 2, H * len(items)), (250, 250, 250))
    d = ImageDraw.Draw(img)
    for row, (name, x) in enumerate(items):
        y0 = row * H
        m = G.metrics(x[:min(len(x), SR * 3)])
        d.text((8, y0 + 3), "%s %.2fs centroid %d Hz phoneDrop %s dB peak %s dB" % (
            name, len(x) / SR, m["centroidHz"], m["phoneDropDb"], m["peakDb"]), fill=(0, 0, 0))
        hop = max(1, len(x) // (W - 20))
        n = len(x) // hop
        env_ = np.abs(x[:n * hop]).reshape(n, hop).max(axis=1)
        top = max(env_.max(), 1e-6)
        for k, v in enumerate(env_):
            px = 10 + int(k / n * (W - 20))
            hh = int(v / top * (H / 2 - 20))
            d.line([(px, y0 + H // 2 + 8 - hh), (px, y0 + H // 2 + 8 + hh)], fill=(60, 90, 200))
        nper = 512 if len(x) < SR * 3 else 2048
        f, t, S = spectrogram(x, fs=SR, nperseg=nper, noverlap=int(nper * 0.85))
        S = np.clip((10 * np.log10(S[:int(nper * 0.18)] + 1e-14) + 120) / 60, 0, 1)
        im = Image.fromarray((255 - S[::-1] * 255).astype(np.uint8)).resize((W - 20, H - 24)).convert("RGB")
        img.paste(im, (W + 10, y0 + 20))
    img.save(path)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "sheet":
        sheet(sys.argv[2] if len(sys.argv) > 2 else os.path.join(G.ROOT, "build", "sfx_r13", "sheet.png"))
    else:
        main()
